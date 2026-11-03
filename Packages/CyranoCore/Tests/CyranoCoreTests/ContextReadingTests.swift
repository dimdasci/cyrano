import Foundation
import Testing

@testable import CyranoCore

/// Context read from a screenshot of the window before the first check (02 C6).
@MainActor @Suite struct ContextReadingTests {
  let screenshot = Data([UInt8]([0x89, 0x50, 0x4E, 0x47]))
  /// The model answers with fields (04 §4.5); Context shows them as lines.
  let ravi = answer(with: "Ravi", language: "English", about: "Ravi asks about pets.")
  let raviLines = "With: Ravi\nLanguage: English\nAbout: Ravi asks about pets.\nFormality: informal"

  func session(_ engine: FakeEngine) -> ProofreadingSession {
    ProofreadingSession(
      original: "I has a cat.", options: CheckOptions(), engine: engine, dictionary: dictionary())
  }

  @Test func contextIsFilledWithTheAnswer() async {
    let session = session(FakeEngine(fixes: [], context: ravi))
    await session.readContext(from: screenshot)

    #expect(session.context == raviLines)
    #expect(session.contextStatus == nil)
    #expect(session.tokens == 10)
  }

  @Test func screenshotAndTextGoToTheModel() async throws {
    let engine = FakeEngine(fixes: [], context: ravi)
    await session(engine).readContext(from: screenshot)

    let call = try #require(engine.contextCalls.first)
    #expect(call.input.count == 1)
    #expect(call.input[0].images == [screenshot])
    #expect(call.input[0].text == "TEXT:\n\"\"\"\nI has a cat.\n\"\"\"")
  }

  @Test func failedReadingSaysWhyAndLeavesContextEmpty() async {
    let engine = FakeEngine(fixes: [])
    engine.failContext(with: .network)
    let session = session(engine)
    await session.readContext(from: screenshot)

    #expect(session.context.isEmpty)
    #expect(session.contextStatus == .failed(.network))
    #expect(session.canPerform(message: ""))
  }

  @Test func readingShowsWhenItStarted() async throws {
    let engine = FakeEngine(fixes: [], context: ravi)
    let session = session(engine)
    engine.holdContext()
    let before = Date()
    let reading = Task { await session.readContext(from: screenshot) }
    while engine.contextCalls.isEmpty { await Task.yield() }

    guard case .reading(let since) = try #require(session.contextStatus) else {
      Issue.record("expected reading")
      return
    }
    #expect(since >= before && since <= Date())
    engine.release()
    await reading.value
  }

  @Test func checkWaitsWhileContextIsRead() async {
    let engine = FakeEngine(fixes: [], context: ravi)
    let session = session(engine)
    engine.holdContext()
    let reading = Task { await session.readContext(from: screenshot) }
    while engine.contextCalls.isEmpty { await Task.yield() }

    #expect(session.isReadingContext)
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
    #expect(session.contextStatus == nil)
    await reading.value
    #expect(engine.openStreams == 0)
    engine.release()
    #expect(session.context == "My own")
  }

  @Test func skipStopsTheCallAndCheckGoesWithoutContext() async {
    let engine = FakeEngine(fixes: ["I have a cat."], context: ravi)
    let session = session(engine)
    engine.holdContext()
    let reading = Task { await session.readContext(from: screenshot) }
    while engine.contextCalls.isEmpty { await Task.yield() }

    session.stopReadingContext()
    #expect(session.contextStatus == nil)
    #expect(session.canPerform(message: ""))
    await reading.value
    #expect(engine.openStreams == 0)
    engine.release()
    #expect(session.context.isEmpty)
    #expect(session.options.language == .sameAsText)
  }

  @Test func closingThePanelWhileReadingReleasesTheSession() async {
    let engine = FakeEngine(fixes: [], context: ravi)
    engine.holdContext()
    weak var released: ProofreadingSession?
    do {
      let session = session(engine)
      released = session
      let reading = Task { await session.readContext(from: screenshot) }
      while engine.contextCalls.isEmpty { await Task.yield() }
      session.stopReadingContext()
      await reading.value
    }
    #expect(released == nil)
    #expect(engine.openStreams == 0)
  }

  @Test func slowReadingTimesOutWithEmptyContext() async {
    let engine = FakeEngine(fixes: [], context: ravi)
    let session = session(engine)
    engine.holdContext()
    await session.readContext(from: screenshot, timeout: .milliseconds(20))

    #expect(session.context.isEmpty)
    #expect(session.contextStatus == .timedOut)
    #expect(session.canPerform(message: ""))
    #expect(engine.openStreams == 0)
    engine.release()
  }

  @Test func tryAgainReadsTheSameScreenshot() async {
    let engine = FakeEngine(fixes: [])
    engine.failContext(with: .network)
    let session = session(engine)
    await session.readContext(from: screenshot)
    engine.answerContext(with: ravi)
    await session.readContextAgain()

    #expect(session.context == raviLines)
    #expect(session.contextStatus == nil)
    #expect(engine.contextCalls.map { $0.input[0].images } == [[screenshot], [screenshot]])
  }

  @Test func typingOrCheckingClearsTheStatus() async {
    let engine = FakeEngine(fixes: ["I have a cat."])
    engine.failContext(with: .network)
    let session = session(engine)
    await session.readContext(from: screenshot)
    session.context = "Ravi"
    #expect(session.contextStatus == nil)

    await session.readContext(from: screenshot)
    #expect(session.contextStatus == .failed(.network))
    await session.check()
    #expect(session.contextStatus == nil)
  }

  @Test func screenshotForContextDoesNotGoToFix() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."], context: ravi)
    let session = session(engine)
    await session.readContext(from: screenshot)
    await session.check()

    let input = try #require(engine.fixCalls.first?.input)
    #expect(input.allSatisfy { $0.images.isEmpty })
    #expect(input[0].text.contains("About: Ravi asks about pets."))
  }

  @Test func theAnswerIsAskedForAsFields() async throws {
    let engine = FakeEngine(fixes: [], context: ravi)
    await session(engine).readContext(from: screenshot)

    let call = try #require(engine.contextCalls.first)
    #expect(call.schema == ConversationContext.schema)
  }

  /// The model fills the fields in the order sent: whether the draft starts a new topic is
  /// decided before the topic.
  @Test func formatIsAskedForBeforeTheTopic() {
    let json = String(decoding: ConversationContext.schema.json, as: UTF8.self)
    let fields = ["with", "language", "format", "about", "style", "formality"]
    let positions = fields.compactMap { json.range(of: "\"\($0)\":{")?.lowerBound }
    #expect(positions.count == fields.count)
    #expect(positions == positions.sorted())
  }

  @Test func conversationLanguageBecomesTheOutputLanguage() async {
    for (name, language) in [("Spanish", OutputLanguage.spanish), ("English", .englishUS)] {
      let session = session(FakeEngine(fixes: [], context: answer(language: name)))
      await session.readContext(from: screenshot)
      #expect(session.options.language == language)
    }
  }

  @Test func languageNotOfferedInThePanelStaysAuto() async {
    let session = session(FakeEngine(fixes: [], context: answer(language: "Portuguese")))
    await session.readContext(from: screenshot)

    #expect(session.options.language == .sameAsText)
    #expect(session.context.contains("Language: Portuguese"))
  }

  @Test func languageChosenInThePanelIsKept() async {
    let session = session(FakeEngine(fixes: [], context: answer(language: "Spanish")))
    session.options.language = .german
    await session.readContext(from: screenshot)

    #expect(session.options.language == .german)
  }

  @Test func nothingOnScreenLeavesContextEmpty() async {
    let session = session(FakeEngine(fixes: [], context: answer()))
    await session.readContext(from: screenshot)

    #expect(session.context.isEmpty)
    #expect(session.contextStatus == .nothingFound)
    #expect(session.options.language == .sameAsText)
  }

  @Test func answerThatIsNotFieldsIsAFailure() async {
    let session = session(FakeEngine(fixes: [], context: "People: Ravi"))
    await session.readContext(from: screenshot)

    #expect(session.context.isEmpty)
    #expect(session.contextStatus == .failed(.failed("The answer was not the fields asked for.")))
  }
}

private func answer(with: String? = nil, language: String? = nil, about: String? = nil) -> String {
  let formality: String? = with == nil && language == nil && about == nil ? nil : "informal"
  let fields: [(String, String?)] = [
    ("with", with), ("language", language), ("about", about), ("format", nil), ("style", nil),
    ("formality", formality),
  ]
  let json = fields.map { key, value in "\"\(key)\": " + (value.map { "\"\($0)\"" } ?? "null") }
  return "{" + json.joined(separator: ", ") + "}"
}
