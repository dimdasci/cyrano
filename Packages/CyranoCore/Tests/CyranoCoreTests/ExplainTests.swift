import Testing

@testable import CyranoCore

extension Version {
  /// The reasons of a corrected version; nil for a translation.
  var explanations: Explanations? {
    guard case .corrections(_, let explanations) = edit else { return nil }
    return explanations
  }
}

/// Reasons for the changes of a version arrive after it (04 §4.4).
@MainActor @Suite struct ExplainTests {
  func check(explaining answer: String = FakeEngine.grammarReason) async -> (FakeEngine, Version?) {
    let engine = FakeEngine(fixes: ["I have a cat."], explanation: answer)
    let session = ProofreadingSession(
      original: "I has a cat.", options: CheckOptions(), engine: engine, dictionary: dictionary())
    await session.check()
    return (engine, session.versions.first)
  }

  @Test func explainGetsTheNumberedChanges() async throws {
    let (engine, _) = await check()
    let call = try #require(engine.calls.first { $0.instructions == Prompts.explain })
    let expected =
      "Original: I has a cat.\nCorrected: I have a cat.\nChanges:\n1. \"has\" → \"have\""
    #expect(call.input.first?.text == expected)
  }

  @Test func anUnreadableAnswerLeavesNoReasons() async {
    let (_, version) = await check(explaining: "Sorry, I can't.")
    #expect(version?.explanations == .unavailable)
  }

  @Test func reasonsForUnknownChangesAreDropped() async {
    let answer = """
      {"items":[{"id":1,"category":"spelling","reason":"Verb."},\
      {"id":7,"category":"style","reason":"Other."}]}
      """
    let (_, version) = await check(explaining: answer)
    let reason = Explanation(category: .spelling, reason: "Verb.")
    #expect(version?.explanations == .ready([1: reason]))
  }
}
