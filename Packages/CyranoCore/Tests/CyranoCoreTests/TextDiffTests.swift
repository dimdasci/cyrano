import Testing

@testable import CyranoCore

@Suite struct TextDiffTests {
  @Test func identicalTextsHaveNoChanges() {
    let diff = TextDiff(old: "Hello there", new: "Hello there")
    #expect(diff.changes.isEmpty)
    #expect(diff.segments == [.same("Hello there")])
  }

  @Test func replacedWordIsOneChange() {
    let diff = TextDiff(old: "yes I noted this.", new: "yes I noticed this.")
    #expect(diff.changes.map(\.words) == [["noted", "noticed"]])
  }

  @Test func changesSeparatedByOneWordAreMerged() {
    let diff = TextDiff(
      old: "this PRs actually didn't relate", new: "these PRs actually weren't related")
    #expect(
      diff.changes.map(\.words) == [
        ["this", "these"],
        ["didn't relate", "weren't related"],
      ])

    let merged = TextDiff(old: "a b c d", new: "x b y d")
    #expect(merged.changes.map(\.words) == [["a b c", "x b y"]])
  }

  @Test func changesAreNumberedFromOne() {
    let diff = TextDiff(old: "one two three four five", new: "uno two three four cinco")
    #expect(diff.changes.map(\.id) == [1, 2])
  }

  @Test func segmentsRebuildTheNewText() {
    let old = "Meanwhie I want to sketch\nsome dashboards"
    let new = "Meanwhile, I want to sketch\nsome dashboards today"
    #expect(TextDiff(old: old, new: new).newText == new)
  }

  @Test func rejectingAChangeRestoresTheOldWords() {
    let diff = TextDiff(old: "I has a cat and a dog", new: "I have a cat and two dogs")
    let first = diff.changes[0]
    #expect(diff.text(rejecting: first) == "I has a cat and two dogs")
  }

  @Test func whitespaceOnlyEditsAreNotChanges() {
    let diff = TextDiff(old: "Hi  there", new: "Hi there")
    #expect(diff.changes.isEmpty)
    #expect(diff.newText == "Hi there")
  }
}
