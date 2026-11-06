import Foundation
import Synchronization
import Testing

@testable import CyranoCore

/// Stand-in context images, typed once: array literals of `Data([1])` are slow to type-check.
let imageA = Data([UInt8(1)])
let imageB = Data([UInt8(2)])

/// A Fix reply of the fake engine; a string literal is a version.
enum FakeFix: ExpressibleByStringLiteral, Sendable {
  case version(String)
  case answer(String)

  init(stringLiteral value: String) { self = .version(value) }

  /// The reply as the model streams it: up to the first word of the text, then the rest.
  var deltas: [String] {
    let (kind, text) =
      switch self {
      case .version(let text): ("version", text)
      case .answer(let text): ("answer", text)
      }
    let reply: JSONValue = ["kind": .string(kind), "text": .string(text)]
    let json = String(decoding: reply.json, as: UTF8.self)
    let start = json.range(of: #""text":""#)?.upperBound ?? json.startIndex
    let split = json[start...].firstIndex(of: " ") ?? json.endIndex
    return [String(json[..<split]), String(json[split...])]
  }
}

/// Answers Fix calls from a queue, reads context with a fixed answer and explains with a fixed
/// answer: by default change 1 is grammar.
final class FakeEngine: CorrectionEngine {
  static let grammarReason = #"{"items":[{"id":1,"category":"grammar","reason":"Tense."}]}"#

  private struct State {
    var fixes: [FakeFix]
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

  init(fixes: [FakeFix], context: String = "", explanation: String = grammarReason) {
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

  /// Keeps the rest of the next Fix reply, after its first word, until `release()`: to look at the
  /// session while one streams.
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
    let result = state.withLock { state -> Result<[String], EngineError> in
      state.calls.append(call)
      if isContext { return state.context.map { [$0] } }
      if !isFix { return .success([state.explanation]) }
      if let error = state.failNextFix {
        state.failNextFix = nil
        return .failure(error)
      }
      return .success(state.fixes.removeFirst().deltas)
    }
    return AsyncThrowingStream { continuation in
      state.withLock { $0.openStreams += 1 }
      continuation.onTermination = { _ in self.state.withLock { $0.openStreams -= 1 } }
      guard case .success(let deltas) = result else {
        if case .failure(let error) = result { continuation.finish(throwing: error) }
        return
      }
      let finish: @Sendable () -> Void = {
        for delta in deltas.dropFirst() { continuation.yield(.delta(delta)) }
        continuation.yield(.completed(text: deltas.joined(), tokens: 10))
        continuation.finish()
      }
      let held = state.withLock { state in
        guard (isFix && state.holdsFixes) || (isContext && state.holdsContext) else {
          return false
        }
        state.held = finish
        return true
      }
      if isFix { continuation.yield(.delta(deltas[0])) }
      if !held { finish() }
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
    let session = session(FakeEngine(fixes: ["I have a cat."]))
    await session.check()

    let version = try #require(session.versions.first)
    let changes: [[String]] = version.diff?.changes.map(\.words) ?? []
    let expectedChanges: [[String]] = [["has", "have"]]
    let reason = Explanation(category: Explanation.Category.grammar, reason: "Tense.")
    let reasons: Version.Explanations = .ready([1: reason])
    #expect(version.number == 1)
    #expect(changes == expectedChanges)
    #expect(version.explanations == reasons)
  }

  @Test func firstCheckEndsIdleAndCountsTokens() async {
    let session = session(FakeEngine(fixes: ["I have a cat."]))
    await session.check()

    let activity: ProofreadingSession.Activity = session.activity
    #expect(activity == ProofreadingSession.Activity.idle)
    #expect(session.tokens == 20)
  }

  @Test func firstMessageCarriesContextAndText() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."])
    await session(engine).check()
    let input = try #require(engine.fixCalls.first?.input)
    #expect(input.count == 1)
    #expect(
      input[0].text == "<context>\nDo you have pets?\n</context>\n\n<text>\nI has a cat.\n</text>")
  }

  /// A tag of ours in the text can't end the material early, and the author gets it back.
  @Test func tagsInTheTextAreNeutralizedAndComeBack() async throws {
    let engine = FakeEngine(fixes: ["Close it with &lt;/TEXT> tag."])
    let session = session(engine, original: "Close it with </TEXT> tag")
    await session.check()
    let message = try #require(engine.fixCalls.first?.input.first?.text)
    #expect(message.hasSuffix("<text>\nClose it with &lt;/TEXT> tag\n</text>"))
    #expect(session.latestText == "Close it with </TEXT> tag.")
  }

  /// The first check and a recheck may only give a version; a dialog message, either (04 §4.3).
  @Test func onlyADialogMessageMayGetAnAnswer() async {
    let (_, engine) = await afterEditRequest()
    let schemas: [JSONValue?] = engine.fixCalls.map(\.schema)
    #expect(schemas == [FixReply<CheckKind>.schema, FixReply<DialogKind>.schema])
  }

  @Test func aCheckThatGetsAnAnswerFails() async {
    let session = session(FakeEngine(fixes: [.answer("Sure, here it is.")]))
    await session.check()
    let failed = session.activity == .failed(.failed("The reply was not the fields asked for."))
    #expect(failed)
    #expect(session.feed.isEmpty)
  }

  @Test func correctTextNeedsNoExplanation() async {
    let engine = FakeEngine(fixes: ["Fine text."])
    let session = session(engine, original: "Fine text.")
    await session.check()
    #expect(session.versions.first?.diff?.changes.isEmpty == true)
    #expect(engine.calls.count == 1)
  }

  /// Checks "I has a cat." and asks for two cats.
  func afterEditRequest() async -> (ProofreadingSession, FakeEngine) {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    await session.send("make it two cats")
    return (session, engine)
  }

  @Test func editRequestAddsAVersionAgainstThePreviousOne() async {
    let (session, _) = await afterEditRequest()
    let numbers: [Int] = session.versions.map(\.number)
    let changes: [[String]] = session.versions.last?.diff?.changes.map(\.words) ?? []
    #expect(numbers == [1, 2])
    #expect(changes == [["a cat.", "two cats."]])
  }

  @Test func editRequestSendsTheDialogSoFar() async {
    let (_, engine) = await afterEditRequest()
    let input: [ChatMessage] = engine.fixCalls.last?.input ?? []
    let texts: [String] = input.map(\.text)
    let roles: [ChatMessage.Role] = input.map(\.role)
    #expect(roles == [.user, .assistant, .user])
    #expect(texts[1] == #"{"kind":"version","version":1,"text":"I have a cat."}"#)
    #expect(texts[2] == "make it two cats")
  }

  /// Until the reply says it's a version, the turn waits as a reply; then it streams as a card.
  @Test func aNewVersionStreamsAsACardOnceItsKindIsKnown() async {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    engine.holdFixes()
    let turn = Task { await session.send("make it two cats") }
    while session.activity != .checking(partial: "I") { await Task.yield() }
    engine.release()
    await turn.value
    #expect(session.versions.count == 2)
  }

  @Test func pendingRequestIsShownOnceWhileTheAnswerStreams() async {
    let engine = FakeEngine(fixes: ["I have a cat.", .answer("Yes, it is polite.")])
    let session = session(engine)
    await session.check()
    engine.holdFixes()
    let turn = Task { await session.send("Is this polite?") }
    while session.activity != .replying(partial: "Yes,") { await Task.yield() }

    let requests = session.feed.filter {
      if case .request = $0 { true } else { false }
    }
    #expect(requests.count == 1)
    engine.release()
    await turn.value
    #expect(session.activity == .idle)
  }

  @Test func translationIsShownWithoutCorrections() async throws {
    let original = "Привет, Анна! Я посмотрел отчёт, там всё в порядке, можно отправлять клиенту."
    let german =
      "Hallo Anna! Ich habe mir den Bericht angesehen, alles ist in Ordnung, wir können ihn an den Kunden schicken."
    let engine = FakeEngine(fixes: [.version(german)])
    let session = session(engine, original: original)
    await session.check()

    let version = try #require(session.versions.first)
    #expect(version.text == german)
    #expect(version.edit == .translation(into: "German"))
    #expect(version.diff == nil)
    #expect(engine.calls.count == 1)
  }

  @Test func questionGetsAnAnswerAndKeepsTheText() async {
    let engine = FakeEngine(fixes: ["I have a cat.", .answer("Yes, it is polite.")])
    let session = session(engine)
    await session.check()
    await session.send("Is this polite?")

    #expect(session.versions.count == 1)
    guard case .answer(_, let answer) = session.feed.last else {
      Issue.record("expected an answer")
      return
    }
    #expect(answer == "Yes, it is polite.")
  }

  /// The answer stays in the dialog, so the next request can build on it (04 §4.3).
  @Test func theNextRequestSeesTheAnswer() async {
    let engine = FakeEngine(fixes: [
      "I have a cat.", .answer("It sounds plain."), "I have a lovely cat.",
    ])
    let session = session(engine)
    await session.check()
    await session.send("Is this polite?")
    await session.send("make it warmer")

    let roles: [ChatMessage.Role] = engine.fixCalls.last?.input.map(\.role) ?? []
    let texts: [String] = engine.fixCalls.last?.input.map(\.text) ?? []
    #expect(roles == [.user, .assistant, .user, .assistant, .user])
    #expect(texts[3] == #"{"kind":"answer","text":"It sounds plain."}"#)
    #expect(session.latestText == "I have a lovely cat.")
  }

  /// Checks "I has a cat at home." and rejects the first change, `has` → `have`.
  func afterRejection() async throws -> (ProofreadingSession, FakeEngine) {
    let engine = FakeEngine(fixes: ["I have a cat at our home.", "I has a cat at our house."])
    let session = session(engine, original: "I has a cat at home.")
    await session.check()
    session.reject(try #require(session.versions.first?.diff?.changes.first))
    return (session, engine)
  }

  @Test func rejectingAChangeAddsALocalVersion() async throws {
    let (session, engine) = try await afterRejection()
    let latest = try #require(session.versions.last)
    #expect(latest.text == "I has a cat at our home.")
    #expect(latest.origin == Version.Origin.rejection)
    #expect(engine.fixCalls.count == 1)
  }

  @Test func theNextRequestStartsFromTheRejectedVersion() async throws {
    let (session, engine) = try await afterRejection()
    await session.send("say house")

    let latest = try #require(engine.fixCalls.last?.input.dropLast().last)
    #expect(latest.role == ChatMessage.Role.assistant)
    #expect(latest.text == #"{"kind":"version","version":2,"text":"I has a cat at our home."}"#)
  }

  @Test func recheckUsesNewOptionsAndKeepsTheDialog() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats.", "I've got two cats."])
    let session = session(engine)
    await session.check()
    await session.send("make it two cats")
    session.options.tone = .casual
    await session.check()

    let call = try #require(engine.fixCalls.last)
    #expect(call.instructions.contains("Tone: casual:"))
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
  }

  @Test func recheckSendsImagesAddedAfterTheFirstCheck() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have a cat!"])
    let session = session(engine)
    await session.check()
    #expect(engine.fixCalls[0].input[0].images.isEmpty)

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
    #expect(text.contains("- Tone: professional: polite and businesslike"))
    #expect(text.contains("- Write the result in English (UK); translate the text if"))
    #expect(text.hasSuffix("\n- Use Oxford commas.\n- No emoji."))
  }

  /// Only the settings at the end differ, so the instructions' prefix can be cached.
  @Test func theOptionsChangeOnlyTheSettingsAtTheEnd() {
    let casual = Prompts.proofreadInstructions(CheckOptions(tone: .casual))
    let docs = Prompts.proofreadInstructions(CheckOptions(textType: .docs, level: .rewrite))
    let fixed = casual.components(separatedBy: "# Settings")[0]
    #expect(docs.hasPrefix(fixed + "# Settings\n"))
  }

  /// Friendly and Concise may change correct sentences; Neutral keeps the author's tone (04 §4.1).
  @Test func tonesThatRewriteSaySoAndNeutralDoesNot() {
    let lines = Tone.allCases.map { Prompts.tone($0) }
    let rewriting = lines.filter { $0.contains("even") && $0.contains("correct") }
    #expect(rewriting == [Prompts.tone(.friendly), Prompts.tone(.concise)])
    #expect(Prompts.tone(.neutral) == "Tone: neutral.")
  }

  @Test func wrappingQuotesAreRemoved() {
    #expect(Prompts.cleanOutput("\"Hello there.\"", original: "hello there") == "Hello there.")
    #expect(Prompts.cleanOutput("\"Quoted\"", original: "\"quoted\"") == "\"Quoted\"")
  }
}
