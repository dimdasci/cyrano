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

  @Test func changesAreNotMergedAcrossAParagraph() {
    let old = "they might me adjusted. \n\nPlease validate if we agree."
    let new = "they may be adjusted.\n\nPlease confirm whether we agree."
    let diff = TextDiff(old: old, new: new)
    #expect(
      diff.changes.map(\.words) == [
        ["might me", "may be"],
        ["validate if", "confirm whether"],
      ])
    #expect(diff.newText == new)
  }

  @Test func wordsOnBothSidesOfABlankLineAreTwoChanges() {
    let diff = TextDiff(
      old: "Hi Jhon,\n\nthanks for the quote.", new: "Hi John,\n\nThanks for the quote.")
    #expect(diff.changes.map(\.words) == [["Jhon,", "John,"], ["thanks", "Thanks"]])
  }

  @Test func changesAreNotMergedAcrossALineBreak() {
    let diff = TextDiff(old: "check a logs\nwrite me", new: "check the logs\nlet me know")
    #expect(diff.changes.map(\.words) == [["a", "the"], ["write me", "let me know"]])
  }

  @Test func rejectingAChangeNextToAParagraphKeepsTheOtherOne() throws {
    let diff = TextDiff(old: "Hi Jhon,\n\nthanks.", new: "Hi John,\n\nThanks.")
    let name = try #require(diff.changes.first)
    #expect(diff.text(rejecting: name) == "Hi Jhon,\n\nThanks.")
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

  @Test func whitespaceOnlyEditsAreNotChanges() {
    let diff = TextDiff(old: "Hi  there", new: "Hi there")
    #expect(diff.changes.isEmpty)
    #expect(diff.newText == "Hi there")
  }
}
