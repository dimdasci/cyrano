// A version card's text as VoiceOver reads it: the version itself, without the removed words the
// card shows struck through. See docs/specs/05-ui.md §2.4, §7.

import AppKit
import CyranoCore

/// Text ranges VoiceOver asks about are ranges of the spoken text; the view maps them to the shown
/// text and back.
final class DiffTextView: MenuTextView {
  var layout: DiffLayout?

  override func accessibilityValue() -> String? {
    layout?.spoken ?? super.accessibilityValue()
  }

  override func accessibilityNumberOfCharacters() -> Int {
    layout.map { $0.spoken.utf16.count } ?? super.accessibilityNumberOfCharacters()
  }

  override func accessibilitySelectedText() -> String? {
    guard let layout else { return super.accessibilitySelectedText() }
    return spokenText(layout.spokenRange(selectedRange()))
  }

  override func accessibilitySelectedTextRange() -> NSRange {
    spoken(super.accessibilitySelectedTextRange())
  }

  override func setAccessibilitySelectedTextRange(_ range: NSRange) {
    super.setAccessibilitySelectedTextRange(shown(range))
  }

  override func accessibilitySelectedTextRanges() -> [NSValue]? {
    super.accessibilitySelectedTextRanges()?.map { NSValue(range: spoken($0.rangeValue)) }
  }

  override func accessibilityVisibleCharacterRange() -> NSRange {
    spoken(super.accessibilityVisibleCharacterRange())
  }

  override func accessibilityString(for range: NSRange) -> String? {
    guard layout != nil else { return super.accessibilityString(for: range) }
    return spokenText(range)
  }

  override func accessibilityAttributedString(for range: NSRange) -> NSAttributedString? {
    guard layout != nil else { return super.accessibilityAttributedString(for: range) }
    return spokenText(range).map { NSAttributedString(string: $0) }
  }

  override func accessibilityRange(forLine line: Int) -> NSRange {
    spoken(super.accessibilityRange(forLine: line))
  }

  override func accessibilityLine(for index: Int) -> Int {
    super.accessibilityLine(for: shown(NSRange(location: index, length: 0)).location)
  }

  override func accessibilityFrame(for range: NSRange) -> NSRect {
    super.accessibilityFrame(for: shown(range))
  }

  override func accessibilityRange(for point: NSPoint) -> NSRange {
    spoken(super.accessibilityRange(for: point))
  }

  override func accessibilityRange(for index: Int) -> NSRange {
    let shownIndex = shown(NSRange(location: index, length: 0)).location
    return spoken(super.accessibilityRange(for: shownIndex))
  }

  override func accessibilityStyleRange(for index: Int) -> NSRange {
    let shownIndex = shown(NSRange(location: index, length: 0)).location
    return spoken(super.accessibilityStyleRange(for: shownIndex))
  }

  /// The spoken text in a range; nil for a range outside it, which would otherwise throw.
  private func spokenText(_ range: NSRange) -> String? {
    guard let spoken = layout?.spoken as NSString?, NSMaxRange(range) <= spoken.length else {
      return nil
    }
    return spoken.substring(with: range)
  }

  private func spoken(_ range: NSRange) -> NSRange {
    layout?.spokenRange(range) ?? range
  }

  private func shown(_ range: NSRange) -> NSRange {
    layout?.shownRange(range) ?? range
  }
}
