import Foundation
import Synchronization
import Testing

@testable import CyranoCore

/// Stand-in context images, typed once: array literals of `Data([1])` are slow to type-check.
let imageA = Data([UInt8(1)])
let imageB = Data([UInt8(2)])

/// Answers Fix calls from a queue, reads context with a fixed answer, classifies by a keyword and
/// explains with a fixed answer: by default change 1 is grammar.
final class FakeEngine: CorrectionEngine {
  static let grammarReason = #"{"items":[{"id":1,"category":"grammar","reason":"Tense."}]}"#

  private struct State {
    var fixes: [String]
    var context: Result<String, EngineError>
    var explanation: String
    var calls: [ModelCall] = []
    var failNextFix: EngineError?
    var holdsFixes = false
    var holdsContext = false
    var held: (@Sendable () -> Void)?
    var openStreams = 0
  }

  private let state: Mutex<State>

  init(fixes: [String], context: String = "", explanation: String = grammarReason) {
    state = Mutex(State(fixes: fixes, context: .success(context), explanation: explanation))
  }

  var calls: [ModelCall] { state.withLock { $0.calls } }
  /// Answers not yet finished, failed or cancelled: a stopped call must not stay open.
  var openStreams: Int { state.withLock { $0.openStreams } }
  var fixCalls: [ModelCall] { calls.filter { $0.instructions.hasPrefix("You are a proofreader") } }
  var contextCalls: [ModelCall] { calls.filter { $0.instructions == Prompts.readContext } }

  func failNextFix(with error: EngineError) { state.withLock { $0.failNextFix = error } }

  func failContext(with error: EngineError) { state.withLock { $0.context = .failure(error) } }

  func answerContext(with answer: String) { state.withLock { $0.context = .success(answer) } }

  /// Keeps the next Fix answers until `release()`, to look at the session while one streams.
  func holdFixes() { state.withLock { $0.holdsFixes = true } }

  /// Keeps the context answer until `release()`.
  func holdContext() { state.withLock { $0.holdsContext = true } }

  func release() {
    let answer = state.withLock { state in
      defer { state.held = nil }
      return state.held
    }
    answer?()
  }

  func respond(_ call: ModelCall) -> AsyncThrowingStream<ResponseUpdate, any Error> {
    let isFix = call.instructions.hasPrefix("You are a proofreader")
    let isContext = call.instructions == Prompts.readContext
    let result = state.withLock { state -> Result<String, EngineError> in
      state.calls.append(call)
      if isContext { return state.context }
      if call.instructions == Prompts.classify {
        return .success(call.input[0].text.contains("?") ? "question" : "edit")
      }
      if call.schema != nil { return .success(state.explanation) }
      if let error = state.failNextFix {
        state.failNextFix = nil
        return .failure(error)
      }
      return .success(state.fixes.removeFirst())
    }
    return AsyncThrowingStream { continuation in
      state.withLock { $0.openStreams += 1 }
      continuation.onTermination = { _ in self.state.withLock { $0.openStreams -= 1 } }
      let deliver: @Sendable () -> Void = {
        switch result {
        case .success(let text):
          continuation.yield(.delta(text))
          continuation.yield(.completed(text: text, tokens: 10))
          continuation.finish()
        case .failure(let error):
          continuation.finish(throwing: error)
        }
      }
      let held = state.withLock { state in
        guard (isFix && state.holdsFixes) || (isContext && state.holdsContext) else {
          return false
        }
        state.held = deliver
        return true
      }
      if !held { deliver() }
    }
  }
}

@MainActor @Suite struct ProofreadingSessionTests {
  func session(_ engine: FakeEngine, original: String = "I has a cat.") -> ProofreadingSession {
    ProofreadingSession(
      original: original, context: "Do you have pets?", options: CheckOptions(), engine: engine,
      dictionary: dictionary())
  }

  @Test func firstCheckShowsAVersionWithDiffAndReasons() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."])
    let session = session(engine)
    await session.check()

    let version = try #require(session.versions.first)
    #expect(version.number == 1)
    #expect(version.diff?.changes.map(\.words) == [["has", "have"]])
    #expect(version.explanations == .ready([1: Explanation(category: .grammar, reason: "Tense.")]))
    #expect(session.activity == .idle)
    #expect(session.tokens == 20)
  }

  @Test func firstMessageCarriesContextAndText() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."])
    await session(engine).check()
    let input = try #require(engine.fixCalls.first?.input)
    #expect(input.count == 1)
    #expect(input[0].text.hasPrefix("CONTEXT (who I am writing to"))
    #expect(input[0].text.contains("Do you have pets?"))
    #expect(input[0].text.hasSuffix("TEXT:\n\"\"\"\nI has a cat.\n\"\"\""))
  }

  @Test func correctTextNeedsNoExplanation() async {
    let engine = FakeEngine(fixes: ["Fine text."])
    let session = session(engine, original: "Fine text.")
    await session.check()
    #expect(session.versions.first?.diff?.changes.isEmpty == true)
    #expect(engine.calls.allSatisfy { $0.schema == nil })
  }

  @Test func editRequestAddsAVersionAgainstThePreviousOne() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    await session.send("make it two cats")

    #expect(session.versions.map(\.number) == [1, 2])
    #expect(session.versions[1].diff?.changes.map(\.words) == [["a cat.", "two cats."]])
    let input = try #require(engine.fixCalls.last?.input)
    #expect(input.map(\.role) == [.user, .assistant, .user])
    #expect(input[2].text.contains("make it two cats"))
  }

  @Test func pendingRequestIsShownOnceWhileTheAnswerStreams() async {
    let engine = FakeEngine(fixes: ["I have a cat.", "Yes, it is polite."])
    let session = session(engine)
    await session.check()
    engine.holdFixes()
    let turn = Task { await session.send("Is this polite?") }
    while engine.fixCalls.count < 2 { await Task.yield() }

    let requests = session.feed.filter {
      if case .request = $0 { true } else { false }
    }
    #expect(requests.count == 1)
    #expect(session.activity == .replying(partial: ""))
    engine.release()
    await turn.value
    #expect(session.activity == .idle)
  }

  @Test func translationIsShownWithoutCorrections() async throws {
    let original = "Привет, Анна! Я посмотрел отчёт, там всё в порядке, можно отправлять клиенту."
    let german =
      "Hallo Anna! Ich habe mir den Bericht angesehen, alles ist in Ordnung, wir können ihn an den Kunden schicken."
    let engine = FakeEngine(fixes: [german])
    let session = session(engine, original: original)
    await session.check()

    let version = try #require(session.versions.first)
    #expect(version.text == german)
    #expect(version.edit == .translation(into: "German"))
    #expect(version.diff == nil)
    #expect(engine.calls.allSatisfy { $0.schema == nil })
  }

  @Test func questionGetsAnAnswerAndKeepsTheText() async {
    let engine = FakeEngine(fixes: ["I have a cat.", "Yes, it is polite."])
    let session = session(engine)
    await session.check()
    await session.send("Is this polite?")

    #expect(session.versions.count == 1)
    guard case .answer(_, let answer) = session.feed.last else {
      Issue.record("expected an answer")
      return
    }
    #expect(answer == "Yes, it is polite.")
    #expect(engine.fixCalls.last?.input.last?.text.contains("DO NOT rewrite the text") == true)
  }

  @Test func rejectingAChangeAddsALocalVersionTheNextRequestStartsFrom() async throws {
    let engine = FakeEngine(fixes: ["I have a cat at our home.", "I has a cat at our house."])
    let session = session(engine, original: "I has a cat at home.")
    await session.check()
    let first = try #require(session.versions.first?.diff?.changes.first)
    session.reject(first)

    #expect(session.versions.last?.text == "I has a cat at our home.")
    #expect(session.versions.last?.origin == .rejection)
    #expect(engine.fixCalls.count == 1)

    await session.send("say house")
    let latest = try #require(engine.fixCalls.last?.input.dropLast().last)
    #expect(latest.role == .assistant)
    #expect(latest.text == "I has a cat at our home.")
  }

  @Test func recheckUsesNewOptionsAndKeepsTheDialog() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats.", "I've got two cats."])
    let session = session(engine)
    await session.check()
    await session.send("make it two cats")
    session.options.tone = .casual
    await session.check()

    let call = try #require(engine.fixCalls.last)
    #expect(call.instructions.contains("Tone: casual."))
    #expect(call.input.map(\.role) == [.user, .assistant, .user, .assistant, .user])
    #expect(call.input.last?.text == Prompts.recheck)
    #expect(session.versions.last?.origin == .recheck)
  }

  @Test func checkSendsContextImagesWithTheFirstMessage() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."])
    let session = session(engine)
    session.images = [imageA, imageB]
    await session.check()

    let input = try #require(engine.fixCalls.first?.input)
    #expect(input[0].images == [imageA, imageB])
    #expect(input[0].text.hasSuffix(Prompts.imagesNote))
  }

  @Test func recheckSendsImagesAddedAfterTheFirstCheck() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have a cat!"])
    let session = session(engine)
    await session.check()
    #expect(engine.fixCalls[0].input[0].images.isEmpty)
    #expect(!engine.fixCalls[0].input[0].text.contains(Prompts.imagesNote))

    session.images = [imageA]
    await session.check()
    let input = try #require(engine.fixCalls.last?.input)
    #expect(input.map(\.images) == [[imageA], [], []])
    #expect(input.last?.text == Prompts.recheck)
  }

  @Test func dialogAndExplainDoNotRepeatImages() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    session.images = [imageA]
    await session.check()
    await session.send("make it two cats")

    let input = try #require(engine.fixCalls.last?.input)
    #expect(input.map(\.images) == [[imageA], [], []])
    let otherCalls = engine.calls.filter { !engine.fixCalls.contains($0) }
    #expect(!otherCalls.isEmpty)
    #expect(otherCalls.allSatisfy { $0.input.allSatisfy(\.images.isEmpty) })
  }

  @Test func moreThanTenImagesWarn() {
    let session = session(FakeEngine(fixes: []))
    session.images = Array(repeating: imageA, count: 10)
    #expect(!session.hasManyImages)
    session.images.append(imageB)
    #expect(session.hasManyImages)
  }

  @Test func failedCheckDoesNotKeepTheSessionAlive() async {
    let engine = FakeEngine(fixes: [])
    engine.failNextFix(with: .network)
    weak var released: ProofreadingSession?
    do {
      let session = session(engine)
      released = session
      await session.check()
      #expect(session.activity == .failed(.network))
    }
    #expect(released == nil)
  }

  @Test func failedTurnCanBeRetriedWithoutLosingTheText() async {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    engine.failNextFix(with: .network)
    await session.send("two cats")

    #expect(session.activity == .failed(.network))
    #expect(session.feed.count == 1)

    await session.tryAgain()
    #expect(session.activity == .idle)
    #expect(session.latestText == "I have two cats.")
  }
}

@Suite struct PromptTests {
  @Test func instructionsFollowTheOptions() {
    let options = CheckOptions(
      textType: .docs, tone: .professional, level: .errorsOnly, language: .englishUK,
      customInstructions: "Use Oxford commas.\n\nNo emoji.")
    let text = Prompts.proofreadInstructions(options)
    #expect(text.contains("- This is technical documentation"))
    #expect(text.contains("- Fix only clear errors."))
    #expect(text.contains("- Tone: professional."))
    #expect(text.contains("- Write the result in English (UK)."))
    #expect(text.contains("- Use Oxford commas.\n- No emoji.\n- Output only"))
  }

  @Test func wrappingQuotesAreRemoved() {
    #expect(Prompts.cleanOutput("\"Hello there.\"", original: "hello there") == "Hello there.")
    #expect(Prompts.cleanOutput("\"Quoted\"", original: "\"quoted\"") == "\"Quoted\"")
  }
}
