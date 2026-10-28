import Foundation
import Testing

@testable import CyranoCore

/// Replies to each request with the next scripted response and records what was sent.
actor ScriptedTransport: HTTPTransport {
  enum Reply {
    case lines(status: Int, [String])
    case failure(URLError.Code)
  }

  private var replies: [Reply]
  private(set) var requests: [URLRequest] = []

  init(_ replies: [Reply]) { self.replies = replies }

  var sentBodies: [Data] { requests.compactMap(\.httpBody) }

  func data(for request: URLRequest) async throws -> (status: Int, body: Data) {
    let reply = try next(request)
    guard case .lines(let status, let lines) = reply else {
      throw URLError(.notConnectedToInternet)
    }
    return (status, Data(lines.joined(separator: "\n").utf8))
  }

  func stream(for request: URLRequest) async throws -> HTTPStream {
    guard case .lines(let status, let lines) = try next(request) else {
      throw URLError(.timedOut)
    }
    return HTTPStream(
      status: status,
      lines: AsyncThrowingStream { continuation in
        for line in lines { continuation.yield(line) }
        continuation.finish()
      })
  }

  private func next(_ request: URLRequest) throws -> Reply {
    requests.append(request)
    guard !replies.isEmpty else { throw URLError(.badServerResponse) }
    let reply = replies.removeFirst()
    if case .failure(let code) = reply { throw URLError(code) }
    return reply
  }
}

/// Server-sent event lines. Test texts contain no quotes or backslashes.
enum SSE {
  static func delta(_ text: String) -> String {
    #"data: {"type":"response.output_text.delta","delta":"\#(text)"}"#
  }

  static func completed(tokens: Int) -> String {
    #"data: {"type":"response.completed","response":{"usage":{"total_tokens":\#(tokens)}}}"#
  }
}

@Suite struct OpenAIEngineTests {
  let call = ModelCall(instructions: "Be nice.", input: [ChatMessage(.user, "TEXT")])

  func engine(_ transport: ScriptedTransport) -> OpenAIEngine {
    OpenAIEngine(model: .sol, transport: transport, accessToken: { "token-1" })
  }

  func collect(_ engine: OpenAIEngine) async throws -> [ResponseUpdate] {
    var updates: [ResponseUpdate] = []
    for try await update in engine.respond(call) { updates.append(update) }
    return updates
  }

  @Test func streamsTextThenCompletesWithUsage() async throws {
    let transport = ScriptedTransport([
      .lines(
        status: 200,
        ["event: x", SSE.delta("Hello"), "", SSE.delta(" world"), SSE.completed(tokens: 42)])
    ])
    let updates = try await collect(engine(transport))
    #expect(
      updates == [.delta("Hello"), .delta(" world"), .completed(text: "Hello world", tokens: 42)])
  }

  @Test func sendsOnlySupportedFields() async throws {
    let transport = ScriptedTransport([.lines(status: 200, [SSE.completed(tokens: 1)])])
    _ = try await collect(engine(transport))
    let data = try #require(await transport.sentBodies.first)
    let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(body.keys) == ["model", "instructions", "input", "store", "stream", "reasoning"])
    #expect(body["model"] as? String == "gpt-6.1-sol")
    #expect(body["store"] as? Bool == false)
    let request = await transport.requests.first
    #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer token-1")
  }

  @Test func planLimitIsRecognized() async throws {
    let body = #"{"error":{"code":"subscription_sharing_usage_limit_exceeded","message":"x"}}"#
    let transport = ScriptedTransport([.lines(status: 429, [body])])
    await #expect(throws: EngineError.planLimitReached) { try await collect(engine(transport)) }
  }

  @Test func revokedTokenMeansSignedOut() async throws {
    let transport = ScriptedTransport([.lines(status: 401, ["{}"])])
    await #expect(throws: EngineError.notSignedIn) { try await collect(engine(transport)) }
  }

  @Test func networkFailureIsRetriedOnce() async throws {
    let transport = ScriptedTransport([
      .failure(.timedOut), .lines(status: 200, [SSE.delta("ok"), SSE.completed(tokens: 3)]),
    ])
    let updates = try await collect(engine(transport))
    #expect(updates.last == .completed(text: "ok", tokens: 3))

    let failing = ScriptedTransport([.failure(.timedOut), .failure(.notConnectedToInternet)])
    await #expect(throws: EngineError.network) { try await collect(engine(failing)) }
  }

  @Test func streamWithoutCompletionFails() async throws {
    let transport = ScriptedTransport([.lines(status: 200, [SSE.delta("partial")])])
    await #expect(throws: EngineError.self) { try await collect(engine(transport)) }
  }
}
