import Foundation
import Testing

@testable import CyranoCore

/// Context read from a screenshot of the window before the first check (02 C6).
@MainActor @Suite struct ContextReadingTests {
  let screenshot = Data([UInt8]([0x89, 0x50, 0x4E, 0x47]))
  let ravi = "People: Ravi, you; direct message\nReplying to:\nRavi: Do you have pets?"

  func session(_ engine: FakeEngine) -> ProofreadingSession {
    ProofreadingSession(original: "I has a cat.", options: CheckOptions(), engine: engine)
  }

  @Test func contextIsFilledWithTheAnswer() async {
    let session = session(FakeEngine(fixes: [], context: "  \(ravi)\n"))
    await session.readContext(from: screenshot)

    #expect(session.context == ravi)
    #expect(session.activity == .idle)
    #expect(session.tokens == 10)
  }

  @Test func screenshotAndTextGoToLuna() async throws {
    let engine = FakeEngine(fixes: [], context: ravi)
    await session(engine).readContext(from: screenshot)

    let call = try #require(engine.contextCalls.first)
    #expect(call.model == .luna)
    #expect(call.input.count == 1)
    #expect(call.input[0].images == [screenshot])
    #expect(call.input[0].text == "TEXT:\n\"\"\"\nI has a cat.\n\"\"\"")
  }

  @Test func noConversationOnScreenLeavesContextEmpty() async {
    let session = session(FakeEngine(fixes: [], context: " \n"))
    await session.readContext(from: screenshot)
    #expect(session.context.isEmpty)
    #expect(session.activity == .idle)
  }

  @Test func checkWaitsWhileContextIsRead() async {
    let engine = FakeEngine(fixes: [], context: ravi)
    let session = session(engine)
    engine.holdContext()
    let reading = Task { await session.readContext(from: screenshot) }
    while engine.contextCalls.isEmpty { await Task.yield() }

    #expect(session.activity == .readingContext)
    #expect(!session.canPerform(message: ""))
    engine.release()
    await reading.value
    #expect(session.canPerform(message: ""))
  }

  @Test func typingInContextStopsReadingAndKeepsTheText() async {
    let engine = FakeEngine(fixes: [], context: ravi)
    let session = session(engine)
    engine.holdContext()
    let reading = Task { await session.readContext(from: screenshot) }
    while engine.contextCalls.isEmpty { await Task.yield() }

    session.context = "My own"
    #expect(session.activity == .idle)
    engine.release()
    await reading.value
    #expect(session.context == "My own")
  }

  @Test func slowReadingTimesOutWithEmptyContext() async {
    let engine = FakeEngine(fixes: [], context: ravi)
    let session = session(engine)
    engine.holdContext()
    await session.readContext(from: screenshot, timeout: .milliseconds(20))

    #expect(session.context.isEmpty)
    #expect(session.activity == .idle)
    #expect(session.canPerform(message: ""))
    engine.release()
  }

  @Test func screenshotForContextDoesNotGoToFix() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."], context: ravi)
    let session = session(engine)
    await session.readContext(from: screenshot)
    await session.check()

    let input = try #require(engine.fixCalls.first?.input)
    #expect(input.allSatisfy { $0.images.isEmpty })
    #expect(input[0].text.contains("Ravi: Do you have pets?"))
  }
}
