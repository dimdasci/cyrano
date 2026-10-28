// Responses API over the ChatGPT plan. See docs/specs/02-tech-decisions.md M2, M12, M13.

import Foundation

public struct OpenAIEngine: CorrectionEngine {
  public typealias TokenProvider = @Sendable () async throws -> String

  static let endpoint = URL(string: "https://api.openai.com/v1/responses")

  let model: Model
  let transport: any HTTPTransport
  let accessToken: TokenProvider

  public init(model: Model, transport: any HTTPTransport, accessToken: @escaping TokenProvider) {
    self.model = model
    self.transport = transport
    self.accessToken = accessToken
  }

  public func respond(_ call: ModelCall) -> AsyncThrowingStream<ResponseUpdate, any Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          try await respondRetryingOnce(call) { continuation.yield($0) }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  /// A network failure before any text arrived is retried once (M13).
  private func respondRetryingOnce(
    _ call: ModelCall, yield: (ResponseUpdate) -> Void
  ) async throws {
    var receivedText = false
    do {
      try await respondOnce(call) { update in
        receivedText = true
        yield(update)
      }
    } catch EngineError.network where !receivedText {
      try await respondOnce(call, yield: yield)
    }
  }

  private func respondOnce(_ call: ModelCall, yield: (ResponseUpdate) -> Void) async throws {
    let request = try await makeRequest(call)
    let response: HTTPStream
    do {
      response = try await transport.stream(for: request)
    } catch is URLError {
      throw EngineError.network
    }
    guard response.status == 200 else {
      throw APIError.engineError(status: response.status, body: try await body(response))
    }
    try await read(response, yield: yield)
  }

  private func read(_ response: HTTPStream, yield: (ResponseUpdate) -> Void) async throws {
    var text = ""
    do {
      for try await line in response.lines {
        switch StreamEvent(line: line) {
        case .delta(let delta):
          text += delta
          yield(.delta(delta))
        case .completed(let tokens):
          return yield(.completed(text: text, tokens: tokens))
        case .failed(let error): throw error
        case nil: continue
        }
      }
    } catch is URLError {
      throw EngineError.network
    }
    throw EngineError.failed("The response ended before it was complete.")
  }

  private func makeRequest(_ call: ModelCall) async throws -> URLRequest {
    guard let endpoint = Self.endpoint else { throw EngineError.failed("Bad endpoint") }
    var request = URLRequest(url: endpoint, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(ResponsesRequest.body(model: model, call: call))
    return request
  }

  private func body(_ response: HTTPStream) async throws -> String {
    var lines: [String] = []
    for try await line in response.lines { lines.append(line) }
    return lines.joined(separator: "\n")
  }
}
