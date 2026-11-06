import CyranoCore
import Foundation
import Synchronization
import Testing

@testable import CyranoEval

/// Fix replies come from a queue: a text ending in "!" is an answer, anything else a version.
/// Explain gives change 1 a fixed reason.
final class ScriptedEngine: CorrectionEngine {
  private let state: Mutex<(fixes: [String], calls: [ModelCall], failsFix: Bool)>

  init(fixes: [String], failsFix: Bool = false) {
    state = Mutex((fixes, [], failsFix))
  }

  var fixCalls: [ModelCall] {
    state.withLock { $0.calls }.filter { !$0.instructions.hasPrefix("You explain") }
  }

  func respond(_ call: ModelCall) -> AsyncThrowingStream<ResponseUpdate, any Error> {
    let answer = state.withLock { state -> String? in
      state.calls.append(call)
      if call.instructions.hasPrefix("You explain") {
        return #"{"items":[{"id":1,"category":"grammar","reason":"Subject-verb agreement."}]}"#
      }
      guard !state.failsFix else { return nil }
      let text = state.fixes.removeFirst()
      let kind = text.hasSuffix("!") ? "answer" : "version"
      return #"{"kind":"\#(kind)","text":"\#(text)"}"#
    }
    return AsyncThrowingStream { continuation in
      if let answer {
        continuation.yield(.completed(text: answer, tokens: 10))
        continuation.finish()
      } else {
        continuation.finish(throwing: EngineError.network)
      }
    }
  }
}

/// The fix eval writes what the panel would show for each case; a person judges it (04 §5).
@MainActor @Suite struct FixRunTests {
  func cases(_ json: String) throws -> [FixCase] {
    try JSONDecoder().decode([FixCase].self, from: Data(json.utf8))
  }

  @Test func caseWithoutOptionsChecksAsThePanelOpensByDefault() throws {
    let item = try #require(
      try cases(#"[{ "id": "a", "source": "synthetic", "text": "I has it", "criteria": [] }]"#)
        .first)

    #expect(item.options == CheckOptions())
    #expect(item.context.isEmpty)
    #expect(item.dictionary.isEmpty)
    #expect(item.turns.isEmpty)
  }

  static let fullCase = #"""
    [{ "id": "b", "source": "real", "textType": "email", "tone": "friendly",
       "level": "errorsOnly", "language": "russian", "customInstructions": "No dashes",
       "context": "Ravi, a colleague", "dictionary": ["k8s"], "text": "Hi",
       "criteria": ["fixed"], "turns": [{ "message": "Why?", "criteria": ["an answer"] }],
       "heldOut": true }]
    """#

  @Test func caseSetsHeaderOptions() throws {
    let item = try #require(try cases(Self.fullCase).first)
    let options = CheckOptions(
      textType: .email, tone: .friendly, level: .errorsOnly, language: .russian,
      customInstructions: "No dashes")

    #expect(item.options == options)
    #expect(item.source == FixCase.Source.real)
    #expect(item.heldOut)
  }

  @Test func caseSetsContextDictionaryAndTurns() throws {
    let item = try #require(try cases(Self.fullCase).first)
    let dictionary: [String] = ["k8s"]
    let messages: [String] = item.turns.map(\.message)
    let criteria: [[String]] = item.turns.map(\.criteria)
    let expectedCriteria: [[String]] = [["an answer"]]

    #expect(item.context == "Ravi, a colleague")
    #expect(item.dictionary == dictionary)
    #expect(messages == ["Why?"])
    #expect(criteria == expectedCriteria)
  }

  @Test func repositoryCasesDecodeAndHaveCriteria() throws {
    let file = URL(filePath: #filePath).deletingLastPathComponent()
      .appending(path: "../../../../evals/fix/cases.json").standardized
    let cases = try JSONDecoder().decode([FixCase].self, from: Data(contentsOf: file))

    #expect(cases.count >= 30)
    #expect(Set(cases.map(\.id)).count == cases.count)
    #expect(
      cases.allSatisfy { !$0.criteria.isEmpty && $0.turns.allSatisfy { !$0.criteria.isEmpty } })
  }

  @Test func reportShowsEveryVersionChangeReasonAnswerAndCriterion() async throws {
    let json = #"""
      [{ "id": "jargon", "source": "synthetic", "context": "Ravi", "dictionary": ["k8s"],
         "text": "I has fixed k8s", "criteria": ["has → have"],
         "turns": [{ "message": "Is it polite?", "criteria": ["an answer, no version"] },
                   { "message": "make it shorter", "criteria": ["shorter"] }] }]
      """#
    let item = try #require(try cases(json).first)
    let engine = ScriptedEngine(fixes: ["I have fixed k8s", "Yes, it is!", "Fixed k8s"])

    let report = await FixRun(engine: engine, models: ModelChoice()).report(item)

    #expect(!report.failed)
    for line in [
      "## jargon · synthetic", "Message · Neutral · Fluency · Same as Text", "Context: Ravi",
      "Dictionary: k8s", "> I has fixed k8s", "**Version 1** (check)", "> I have fixed k8s",
      #"1. "has" → "have" — grammar: Subject-verb agreement."#, "- has → have",
      "**Message**: Is it polite?", "**Answer**: Yes, it is!",
      "- an answer, no version", "**Message**: make it shorter",
      "**Version 2** (request)", "> Fixed k8s", "- shorter",
    ] {
      #expect(report.markdown.contains(line), "missing \(line)")
    }
    let first = try #require(engine.fixCalls.first?.input.first?.text)
    #expect(first.contains(#"Keep these words exactly as written: "k8s"."#))
    #expect(first.hasPrefix("<context>\nRavi\n</context>"))
  }

  @Test func failedCallEndsTheCaseWithTheError() async throws {
    let json = #"""
      [{ "id": "down", "source": "synthetic", "text": "I has", "criteria": ["fixed"],
         "turns": [{ "message": "Why?", "criteria": [] }] }]
      """#
    let item = try #require(try cases(json).first)

    let report = await FixRun(
      engine: ScriptedEngine(fixes: [], failsFix: true), models: ModelChoice()
    )
    .report(item)

    #expect(report.failed)
    #expect(report.markdown.contains("**ERROR**: network"))
    #expect(!report.markdown.contains("Why?"))
  }
}
