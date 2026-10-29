// One version of the text with its diff, summary, changes and actions. See docs/specs/05-ui.md §2.4.

import AppKit
import CyranoCore
import SwiftUI

struct VersionCard: View {
  struct Actions {
    let copy: (String) -> Void
    let reject: (Change) -> Void
    let selectionItem: (String) -> DictionaryItem
    let changeItems: (Change) -> [DictionaryItem]
  }

  let version: Version
  let isLatest: Bool
  let actions: Actions
  @State private var showsChanges = false

  var body: some View {
    Card(title: "Version \(version.number)") {
      SelectableText(text: DiffText.attributed(version)) { selection in
        TermDictionary.term(fromSelection: selection).map(actions.selectionItem)
      }
      HStack {
        summaryButton
        Spacer()
        copyButton
      }
      if showsChanges {
        ChangeList(version: version, canReject: isLatest, actions: actions)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Version \(version.number), \(summary)")
  }

  @ViewBuilder private var summaryButton: some View {
    if case .translation(let language) = version.edit {
      Text("Translated to \(language)").foregroundStyle(.secondary)
    } else if version.changes.isEmpty {
      Text("✓ No changes needed").foregroundStyle(.secondary)
    } else {
      Button((showsChanges ? "▾ " : "▸ ") + summary) { showsChanges.toggle() }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
  }

  /// The latest version's Copy is the prominent one.
  @ViewBuilder private var copyButton: some View {
    if isLatest {
      Button("Copy") { actions.copy(version.text) }
        .buttonStyle(.borderedProminent)
    } else {
      Button("Copy") { actions.copy(version.text) }
    }
  }

  private var summary: String {
    let changes = version.changes
    switch version.edit {
    case .translation(let language):
      return "Translated to \(language)"
    case .corrections(_, .pending):
      return "Explaining…"
    case .corrections(_, .unavailable):
      return plural(changes.count, "change")
    case .corrections(_, .ready(let reasons)):
      let style = changes.count { reasons[$0.id]?.category == .style }
      let fixes = changes.count - style
      let parts = [
        fixes > 0 ? plural(fixes, "fix", "fixes") : nil,
        style > 0 ? plural(style, "style suggestion") : nil,
      ]
      return parts.compactMap(\.self).joined(separator: " · ")
    }
  }
}

func plural(_ count: Int, _ one: String, _ many: String? = nil) -> String {
  "\(count) \(count == 1 ? one : many ?? one + "s")"
}

private struct ChangeList: View {
  let version: Version
  let canReject: Bool
  let actions: VersionCard.Actions

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(version.changes) { change in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          let reason = version.reasons[change.id]
          Text(reason?.category == .style ? "◇" : "●")
            .foregroundStyle(reason?.category == .style ? .blue : .green)
          VStack(alignment: .leading, spacing: 2) {
            Text("\(change.words[0]) → \(change.words[1])").font(
              .system(.body, design: .monospaced))
            if let reason { Text(reason.reason).foregroundStyle(.secondary) }
          }
          Spacer()
          if canReject {
            Button("Reject", systemImage: "xmark") { actions.reject(change) }
              .labelStyle(.iconOnly)
              .buttonStyle(.plain)
              .help("Reject this change")
          }
        }
        // The whole row, gaps included, opens the menu.
        .contentShape(Rectangle())
        .contextMenu { neverChange(change) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(change.words[0]), replaced with \(change.words[1]), "
            + (version.reasons[change.id]?.category == .style ? "style suggestion" : "error"))
      }
    }
  }
}

extension ChangeList {
  /// Only the latest version's changes can be rejected.
  @ViewBuilder fileprivate func neverChange(_ change: Change) -> some View {
    if canReject {
      ForEach(actions.changeItems(change), id: \.title) { item in
        Button(item.title, action: item.perform)
      }
    }
  }
}

extension Version {
  fileprivate var changes: [Change] { diff?.changes ?? [] }

  fileprivate var reasons: [Int: Explanation] {
    guard case .corrections(_, .ready(let reasons)) = edit else { return [:] }
    return reasons
  }
}

/// Removed words struck through and dimmed; added words underlined on a tinted background,
/// solid for errors and dashed for style. Color is never the only signal. A translation is
/// shown as plain text.
enum DiffText {
  private static let plain: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor,
  ]

  static func attributed(_ version: Version) -> NSAttributedString {
    guard let diff = version.diff else {
      return NSAttributedString(string: version.text, attributes: plain)
    }
    let result = NSMutableAttributedString()
    for segment in diff.segments {
      switch segment {
      case .same(let text):
        result.append(NSAttributedString(string: text, attributes: plain))
      case .changed(let change):
        result.append(attributed(change, isStyle: version.reasons[change.id]?.category == .style))
      }
    }
    return result
  }

  private static func attributed(_ change: Change, isStyle: Bool) -> NSAttributedString {
    var old = plain
    old[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    old[.foregroundColor] = NSColor.secondaryLabelColor
    var new = plain
    new[.underlineStyle] =
      isStyle
      ? NSUnderlineStyle([.single, .patternDash]).rawValue : NSUnderlineStyle.single.rawValue
    new[.backgroundColor] =
      isStyle
      ? NSColor.systemBlue.withAlphaComponent(0.15) : NSColor.systemGreen.withAlphaComponent(0.2)
    let separator = change.old.isEmpty || change.new.isEmpty ? "" : " "
    let result = NSMutableAttributedString(string: change.old, attributes: old)
    result.append(NSAttributedString(string: separator, attributes: plain))
    result.append(NSAttributedString(string: change.new, attributes: new))
    return result
  }
}
