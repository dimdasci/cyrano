// Responses API over the ChatGPT plan. See docs/specs/02-tech-decisions.md M2, M12, M13.

import Foundation
import Synchronization

public struct OpenAIEngine: CorrectionEngine {
  public typealias TokenProvider = @Sendable () async throws -> String

  static let endpoint = URL(string: "https://api.openai.com/v1/responses")

  let transport: any HTTPTransport
  let accessToken: TokenProvider
  let idleTimeout: Duration

  public init(
    transport: any HTTPTransport, accessToken: @escaping TokenProvider,
    idleTimeout: Duration = .seconds(30)
  ) {
    self.transport = transport
    self.accessToken = accessToken
    self.idleTimeout = idleTimeout
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

  /// A network failure or a timeout before any text arrived is retried once (M13). A stopped call
  /// is not: its request ends with a network error too.
  private func respondRetryingOnce(
    _ call: ModelCall, yield: (ResponseUpdate) -> Void
  ) async throws {
    var receivedText = false
    do {
      try await respondOnce(call) { update in
        receivedText = true
        yield(update)
      }
    } catch let error as EngineError
      where [.network, .timedOut].contains(error) && !receivedText && !Task.isCancelled
    {
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
      for try await event in Self.events(of: response.lines, idle: idleTimeout) {
        switch event {
        case .delta(let delta):
          text += delta
          yield(.delta(delta))
        case .completed(let tokens):
          return yield(.completed(text: text, tokens: tokens))
        case .failed(let error): throw error
        case .progress: continue
        }
      }
    } catch is URLError {
      throw EngineError.network
    }
    throw EngineError.failed("The response ended before it was complete.")
  }

  /// The stream's events; fails with `timedOut` when none arrives for `idle`. The request's own
  /// timeout counts bytes, and the server's keep-alives are bytes: a request it held for 905 s
  /// never timed out (02 M13).
  static func events(
    of lines: AsyncThrowingStream<String, any Error>, idle: Duration
  ) -> AsyncThrowingStream<StreamEvent, any Error> {
    AsyncThrowingStream { continuation in
      let lastEvent = Mutex(ContinuousClock.now)
      let reader = Task {
        do {
          for try await line in lines {
            guard let event = StreamEvent(line: line) else { continue }
            lastEvent.withLock { $0 = .now }
            continuation.yield(event)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      let watchdog = Task {
        while true {
          let deadline = lastEvent.withLock { $0 } + idle
          guard (try? await Task.sleep(until: deadline, clock: .continuous)) != nil else { return }
          if lastEvent.withLock({ $0 }) + idle <= .now { break }
        }
        continuation.finish(throwing: EngineError.timedOut)
      }
      continuation.onTermination = { _ in
        reader.cancel()
        watchdog.cancel()
      }
    }
  }

  private func makeRequest(_ call: ModelCall) async throws -> URLRequest {
    guard let endpoint = Self.endpoint else { throw EngineError.failed("Bad endpoint") }
    var request = URLRequest(url: endpoint, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = ResponsesRequest.body(call).json
    return request
  }

  private func body(_ response: HTTPStream) async throws -> String {
    var lines: [String] = []
    for try await line in response.lines { lines.append(line) }
    return lines.joined(separator: "\n")
  }
}
