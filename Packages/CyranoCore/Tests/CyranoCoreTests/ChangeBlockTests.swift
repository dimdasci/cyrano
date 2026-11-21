import Testing

@testable import CyranoCore

/// The card marks a change as one block: its struck-through words, the space and its new words
/// carry the change, so the line and the fill run under all of them (05 §2.4).
@Suite struct ChangeBlockTests {
  /// "I has have a cat.": "has have" is one block.
  @Test func aReplacementIsOneBlock() {
    let layout = DiffLayout(TextDiff(old: "I has a cat.", new: "I have a cat."))
    let marked: [String] = layout.pieces.filter { $0.change != nil }.map(\.text)
    let ids: Set<Int> = Set(layout.pieces.compactMap { $0.change?.id })
    #expect(marked.joined() == "has have" && ids.count == 1)
  }

  /// A deletion has no new words; its struck-through words carry the mark.
  @Test func aDeletionIsMarked() {
    let layout = DiffLayout(TextDiff(old: "I have a very big cat.", new: "I have a big cat."))
    let marked: String = layout.pieces.filter { $0.change != nil }.map(\.text).joined()
    let unmarked: String = layout.pieces.filter { $0.change == nil }.map(\.text).joined()
    #expect(marked.trimmed == "very" && !unmarked.contains("very"))
  }
}
