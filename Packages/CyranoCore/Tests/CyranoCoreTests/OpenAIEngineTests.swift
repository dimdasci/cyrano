import Foundation
import Testing

@testable import CyranoCore

/// Replies to each request with the next scripted response and records what was sent.
actor ScriptedTransport: HTTPTransport {
  enum Reply {
    case lines(status: Int, [String])
    /// A 200 stream that loses the connection after these lines.
    case broken([String])
    /// A 200 stream that sends these lines and then nothing, with the connection open.
    case silent([String])
    /// A 200 stream that keeps sending keep-alives and nothing else, as a stalled request does.
    case pinging
    /// A 200 stream that sends these lines one at a time, a pause before each.
    case slow([String], pause: Duration)
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
    switch try next(request) {
    case .lines(let status, let lines):
      HTTPStream(status: status, lines: Self.send(lines, end: nil))
    case .broken(let lines): HTTPStream(status: 200, lines: Self.send(lines, end: .connectionLost))
    case .silent(let lines): HTTPStream(status: 200, lines: Self.send(lines, end: .stayOpen))
    case .pinging: HTTPStream(status: 200, lines: Self.keepAlives())
    case .slow(let lines, let pause): HTTPStream(status: 200, lines: Self.slowly(lines, pause))
    case .failure: throw URLError(.timedOut)
    }
  }

  enum End { case connectionLost, stayOpen }

  static func send(_ lines: [String], end: End?) -> AsyncThrowingStream<String, any Error> {
    AsyncThrowingStream { continuation in
      for line in lines { continuation.yield(line) }
      switch end {
      case nil: continuation.finish()
      case .connectionLost: continuation.finish(throwing: URLError(.networkConnectionLost))
      case .stayOpen: break
      }
    }
  }

  static func keepAlives() -> AsyncThrowingStream<String, any Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        while !Task.isCancelled {
          continuation.yield(": keep-alive")
          continuation.yield("event: keepalive")
          continuation.yield(#"data: {"type":"keepalive"}"#)
          try? await Task.sleep(for: .milliseconds(5))
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  static func slowly(_ lines: [String], _ pause: Duration) -> AsyncThrowingStream<String, any Error>
  {
    AsyncThrowingStream { continuation in
      let task = Task {
        for line in lines {
          try? await Task.sleep(for: pause)
          continuation.yield(line)
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
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
  let call = ModelCall(model: .sol, instructions: "Be nice.", input: [ChatMessage(.user, "TEXT")])

  func engine(_ transport: ScriptedTransport, idle: Duration = .seconds(30)) -> OpenAIEngine {
    OpenAIEngine(transport: transport, accessToken: { "token-1" }, idleTimeout: idle)
  }

  func collect(
    _ engine: OpenAIEngine, _ call: ModelCall? = nil
  ) async throws -> [ResponseUpdate] {
    var updates: [ResponseUpdate] = []
    for try await update in engine.respond(call ?? self.call) { updates.append(update) }
    return updates
  }

  /// The JSON body of the first request.
  func sentBody(_ transport: ScriptedTransport) async throws -> [String: Any] {
    let data = try #require(await transport.sentBodies.first)
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
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
    let body = try await sentBody(transport)
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

  static let streamErrors: [(String, EngineError)] = [
    (
      #"data: {"type":"response.failed","response":{"error":{"code":"#
        + #""subscription_sharing_usage_limit_exceeded"}}}"#, .planLimitReached
    ),
    (
      #"data: {"type":"error","error":{"code":"subscription_sharing_usage_unavailable"}}"#,
      .planUsageUnavailable
    ),
  ]

  /// Plan errors arrive in the middle of the stream (M12).
  @Test(arguments: streamErrors)
  func errorsInTheStreamAreRecognized(line: String, error: EngineError) async throws {
    let transport = ScriptedTransport([.lines(status: 200, [SSE.delta("Hel"), line])])
    await #expect(throws: error) { try await collect(engine(transport)) }
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

  /// A retry after text arrived would show that text twice.
  @Test func failureAfterTextIsNotRetried() async throws {
    let transport = ScriptedTransport([
      .broken([SSE.delta("Hel")]), .lines(status: 200, [SSE.completed(tokens: 3)]),
    ])
    await #expect(throws: EngineError.network) { try await collect(engine(transport)) }
    #expect(await transport.requests.count == 1)
  }

  /// The request's own timeout counts bytes, so a stream that stays open without events would
  /// never end (M13).
  @Test func aStreamWithoutEventsTimesOutAndIsRetriedOnce() async throws {
    let stalled = ScriptedTransport([.silent([]), .pinging])
    await #expect(throws: EngineError.timedOut) {
      try await collect(engine(stalled, idle: .milliseconds(50)))
    }
    #expect(await stalled.requests.count == 2)

    let recovering = ScriptedTransport([
      .silent([]), .lines(status: 200, [SSE.delta("ok"), SSE.completed(tokens: 3)]),
    ])
    let updates = try await collect(engine(recovering, idle: .milliseconds(50)))
    #expect(updates.last == .completed(text: "ok", tokens: 3))
  }

  /// Before its first text the model reasons; the server's events about that are progress. The
  /// stream lasts twice the idle timeout, and each pause is a fifth of it: a busy CI runner
  /// stretches a 20 ms pause past 80 ms, a 100 ms one not past 500 ms.
  @Test func slowReasoningEventsThenTextDoNotTimeOut() async throws {
    let working = Array(repeating: #"data: {"type":"response.in_progress"}"#, count: 8)
    let transport = ScriptedTransport([
      .slow(working + [SSE.delta("ok"), SSE.completed(tokens: 3)], pause: .milliseconds(100))
    ])
    let updates = try await collect(engine(transport, idle: .milliseconds(500)))
    #expect(updates.last == .completed(text: "ok", tokens: 3))
    #expect(await transport.requests.count == 1)
  }

  @Test func aStreamThatStallsAfterTextTimesOutWithoutARetry() async throws {
    let transport = ScriptedTransport([
      .silent([SSE.delta("Hel")]), .lines(status: 200, [SSE.completed(tokens: 3)]),
    ])
    await #expect(throws: EngineError.timedOut) {
      try await collect(engine(transport, idle: .milliseconds(50)))
    }
    #expect(await transport.requests.count == 1)
  }

  @Test func streamWithoutCompletionFails() async throws {
    let transport = ScriptedTransport([.lines(status: 200, [SSE.delta("partial")])])
    await #expect(throws: EngineError.self) { try await collect(engine(transport)) }
  }

  /// The request body of a call with an image, a reply and a schema.
  func wireBody() async throws -> [String: Any] {
    let png = Data([0x89, 0x50, 0x4E, 0x47])
    let input = [ChatMessage(.user, "TEXT", images: [png]), ChatMessage(.assistant, "Fixed")]
    let call = ModelCall(
      model: .luna, instructions: "Read.", input: input, schema: ["type": "object"])
    let transport = ScriptedTransport([.lines(status: 200, [SSE.completed(tokens: 1)])])
    _ = try await collect(engine(transport), call)
    return try await sentBody(transport)
  }

  @Test func imagesAndRepliesGoInTheirWireShape() async throws {
    let body = try await wireBody()
    let messages = body["input"] as? [[String: Any]] ?? []
    let content: [[[String: Any]]] = messages.map { $0["content"] as? [[String: Any]] ?? [] }
    let types: [[String]] = content.map { $0.map { $0["type"] as? String ?? "" } }
    let image: String = content.first?.last?["image_url"] as? String ?? ""
    let expectedTypes: [[String]] = [["input_text", "input_image"], ["output_text"]]

    #expect(types == expectedTypes)
    #expect(image == "data:image/png;base64,iVBORw==")
  }

  @Test func modelAndSchemaGoInTheirWireShape() async throws {
    let body = try await wireBody()
    let format = (body["text"] as? [String: Any])?["format"] as? [String: Any] ?? [:]
    let sent: [String] = [
      body["model"] as? String ?? "", format["type"] as? String ?? "",
      (format["strict"] as? Bool).map(String.init) ?? "",
    ]
    let expected: [String] = ["gpt-6-luna", "json_schema", "true"]

    #expect(sent == expected)
  }
}

/// Holds every request open until the caller is cancelled, as URLSession does.
actor HangingTransport: HTTPTransport {
  private(set) var requests = 0

  func data(for request: URLRequest) async throws -> (status: Int, body: Data) {
    throw URLError(.badServerResponse)
  }

  func stream(for request: URLRequest) async throws -> HTTPStream {
    requests += 1
    do {
      try await Task.sleep(for: .seconds(60))
    } catch {
      throw URLError(.cancelled)
    }
    throw URLError(.badServerResponse)
  }
}

@Suite struct OpenAIEngineCancellationTests {
  /// A stopped call ends the request and does not send it again as a network failure.
  @Test func cancelledCallIsNotSentAgain() async {
    let transport = HangingTransport()
    let engine = OpenAIEngine(transport: transport, accessToken: { "token-1" })
    let call = ModelCall(model: .luna, instructions: "Read.", input: [ChatMessage(.user, "TEXT")])
    let consumer = Task {
      for try await _ in engine.respond(call) {}
    }
    while await transport.requests == 0 { await Task.yield() }
    consumer.cancel()
    _ = await consumer.result
    try? await Task.sleep(for: .milliseconds(50))

    #expect(await transport.requests == 1)
  }
}
