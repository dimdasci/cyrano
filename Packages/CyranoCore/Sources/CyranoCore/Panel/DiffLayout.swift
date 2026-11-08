// A version's diff as the card shows it and as VoiceOver reads it. See docs/specs/05-ui.md §2.4,
// §7.

public import Foundation

/// The card shows each change as its removed words, a space and its added words, in one string.
/// VoiceOver reads the version's own text, without the removed words, so the card maps its text
/// ranges between the two.
public struct DiffLayout: Sendable {
  public enum Kind: Hashable, Sendable {
    case same
    case removed
    /// The space between a change's removed and added words.
    case gap
    case added(Change)
  }

  public struct Piece: Hashable, Sendable {
    public let text: String
    public let kind: Kind
  }

  /// What the card shows, in order.
  public let pieces: [Piece]
  /// What VoiceOver reads: the version's text.
  public let spoken: String
  /// Removed words and gaps, as UTF-16 ranges of the shown text, in order.
  private let hidden: [NSRange]

  public init(_ diff: TextDiff) {
    pieces = diff.segments.flatMap { segment -> [Piece] in
      switch segment {
      case .same(let text):
        return [Piece(text: text, kind: .same)]
      case .changed(let change):
        let gap = change.old.isEmpty || change.new.isEmpty ? "" : " "
        return [
          Piece(text: change.old, kind: .removed), Piece(text: gap, kind: .gap),
          Piece(text: change.new, kind: .added(change)),
        ].filter { !$0.text.isEmpty }
      }
    }
    spoken = diff.newText
    var location = 0
    var hidden: [NSRange] = []
    for piece in pieces {
      let length = piece.text.utf16.count
      if piece.isHidden {
        if let last = hidden.last, NSMaxRange(last) == location {
          hidden[hidden.count - 1].length += length
        } else {
          hidden.append(NSRange(location: location, length: length))
        }
      }
      location += length
    }
    self.hidden = hidden
  }

  /// A range of the shown text as a range of the spoken one; hidden text drops out.
  public func spokenRange(_ range: NSRange) -> NSRange {
    let start = spokenIndex(range.location)
    return NSRange(location: start, length: spokenIndex(NSMaxRange(range)) - start)
  }

  /// A range of the spoken text as a range of the shown one. It starts after removed words and
  /// ends before the ones that follow it.
  public func shownRange(_ range: NSRange) -> NSRange {
    let start = shownIndex(range.location, skippingHiddenAtIt: true)
    let end = max(start, shownIndex(NSMaxRange(range), skippingHiddenAtIt: false))
    return NSRange(location: start, length: end - start)
  }

  private func spokenIndex(_ index: Int) -> Int {
    let before = hidden.reduce(0) { sum, range in
      sum + max(0, min(index, NSMaxRange(range)) - range.location)
    }
    return index - before
  }

  private func shownIndex(_ index: Int, skippingHiddenAtIt: Bool) -> Int {
    var shown = index
    for range in hidden {
      guard range.location < shown || (skippingHiddenAtIt && range.location == shown) else { break }
      shown += range.length
    }
    return shown
  }
}

extension DiffLayout.Piece {
  fileprivate var isHidden: Bool {
    switch kind {
    case .removed, .gap: true
    case .same, .added: false
    }
  }
}
