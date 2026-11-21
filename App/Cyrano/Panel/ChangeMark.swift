// How a change is marked, in the card text and in the list of changes. See docs/specs/05-ui.md
// §2.4, §7.

import AppKit
import CyranoCore

/// A thick underline, solid green for an error and dashed blue for style: the line type tells
/// them apart without color. Until the category is known, the line is solid graphite. In the text a
/// fill a few steps lighter than the line shows where the change is, light enough for the text on
/// it, struck-through words too, to keep 4.5:1.
enum ChangeMark {
  /// The line under a change, drawn by AppKit: SwiftUI's underline has no thickness.
  static func line(_ kind: ChangeKind) -> [NSAttributedString.Key: Any] {
    let pattern: NSUnderlineStyle =
      switch kind {
      case .error, .unknown: .thick
      case .style: [.thick, .patternDash]
      }
    return [.underlineStyle: pattern.rawValue, .underlineColor: color(kind)]
  }

  /// The line and the fill, for a change's block in the text: its removed and added words.
  static func text(_ kind: ChangeKind) -> [NSAttributedString.Key: Any] {
    line(kind).merging([.backgroundColor: color(kind).withAlphaComponent(0.16)]) { $1 }
  }

  /// At least 3:1 against the card and against the fill, in both themes and with Increase
  /// Contrast. The light themes take the darker green the system uses with Increase Contrast: its
  /// green gives 2.2:1 on the light card. The dark themes take the lighter blue the system uses with
  /// Increase Contrast: its blue gives 2.9:1 on its own fill. The light graphite is darker than the
  /// system gray, which gives 2.8:1 on its own fill.
  private static func color(_ kind: ChangeKind) -> NSColor {
    switch kind {
    case .error: green
    case .style: blue
    case .unknown: graphite
    }
  }

  private static let green = themed(
    light: NSColor(srgbRed: 0.141, green: 0.541, blue: 0.239, alpha: 1), dark: .systemGreen)
  private static let blue = themed(
    light: .systemBlue, dark: NSColor(srgbRed: 0.251, green: 0.612, blue: 1, alpha: 1))
  private static let graphite = themed(
    light: NSColor(srgbRed: 0.44, green: 0.44, blue: 0.44, alpha: 1), dark: .systemGray)

  private static func themed(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }
  }
}
