// One version of the text with its diff, summary, changes and actions. See docs/specs/05-ui.md §2.4.

import CyranoCore
import SwiftUI

struct VersionCard: View {
  struct Actions {
    let copy: (String) -> Void
    let reject: (Change) -> Void
  }

  let version: Version
  let isLatest: Bool
  let actions: Actions
  @State private var showsChanges = false

  var body: some View {
    Card(title: "Version \(version.number)") {
      Text(DiffText.attributed(version))
        .font(.system(size: 14))
        .textSelection(.enabled)
      HStack {
        summaryButton
        Spacer()
        copyButton
      }
      if showsChanges {
        ChangeList(version: version, canReject: isLatest, reject: actions.reject)
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

  /// The latest version's Copy is the default action, ⇧⌘C from anywhere in the panel.
  @ViewBuilder private var copyButton: some View {
    if isLatest {
      Button("Copy") { actions.copy(version.text) }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut("c", modifiers: [.command, .shift])
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
  let reject: (Change) -> Void

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
            Button("Reject", systemImage: "xmark") { reject(change) }
              .labelStyle(.iconOnly)
              .buttonStyle(.plain)
              .help("Reject this change")
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(change.words[0]), replaced with \(change.words[1]), "
            + (version.reasons[change.id]?.category == .style ? "style suggestion" : "error"))
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
  static func attributed(_ version: Version) -> AttributedString {
    guard let diff = version.diff else { return AttributedString(version.text) }
    var result = AttributedString()
    for segment in diff.segments {
      switch segment {
      case .same(let text):
        result += AttributedString(text)
      case .changed(let change):
        result += attributed(change, isStyle: version.reasons[change.id]?.category == .style)
      }
    }
    return result
  }

  private static func attributed(_ change: Change, isStyle: Bool) -> AttributedString {
    var old = AttributedString(change.old)
    old.strikethroughStyle = .single
    old.foregroundColor = .secondary
    var new = AttributedString(change.new)
    new.underlineStyle = isStyle ? Text.LineStyle(pattern: .dash) : .single
    new.backgroundColor = isStyle ? Color.blue.opacity(0.15) : Color.green.opacity(0.2)
    let separator = change.old.isEmpty || change.new.isEmpty ? "" : " "
    return old + AttributedString(separator) + new
  }
}
