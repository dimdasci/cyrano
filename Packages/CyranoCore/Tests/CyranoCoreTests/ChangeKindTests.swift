import Testing

@testable import CyranoCore

/// A change is an error or a style suggestion only once its reason says so; until then, and when
/// Explain failed or skipped it, its category is unknown (05 §2.4).
@Suite struct ChangeKindTests {
  let diff = TextDiff(old: "I has a big cat today.", new: "I have a big dog today.")
  let grammar = Explanation(category: .grammar, reason: "Tense.")
  let style = Explanation(category: .style, reason: "Reads better.")

  func version(_ explanations: Version.Explanations) -> Version {
    Version(number: 1, text: "", edit: .corrections(diff, explanations), origin: .check)
  }

  func kinds(_ explanations: Version.Explanations) -> [ChangeKind] {
    let version = version(explanations)
    return diff.changes.map { version.kind(of: $0) }
  }

  @Test func aChangeIsUnknownWhileExplaining() {
    #expect(kinds(.pending) == [.unknown, .unknown])
  }

  @Test func aChangeStaysUnknownWhenExplainFailed() {
    #expect(kinds(.unavailable) == [.unknown, .unknown])
  }

  @Test func theReasonGivesTheKind() {
    #expect(kinds(.ready([1: grammar, 2: style])) == [.error, .style])
  }

  @Test func aChangeExplainSkippedStaysUnknown() {
    #expect(kinds(.ready([2: style])) == [.unknown, .style])
  }

  /// A change without a reason isn't counted as a fix.
  @Test func theSummaryDoesNotCountUnknownChangesAsFixes() {
    #expect(version(.ready([2: style])).summary == "1 style suggestion · 1 other change")
  }

  @Test func aRowWithoutItsReasonReadsAsAChange() {
    let label: String = Change(id: 1, old: "has", new: "have").spoken(reason: nil)
    #expect(label == "has, replaced with have, change")
  }
}
