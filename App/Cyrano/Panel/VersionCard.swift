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
    // One layout for what the card shows and what VoiceOver reads, so their ranges match.
    let layout = version.diff.map(DiffLayout.init)
    Card(title: "Version \(version.number)") {
      SelectableText(
        text: DiffText.attributed(version, layout: layout), layout: layout,
        label: "Version \(version.number) text"
      ) { selection in
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
    .accessibilityLabel("Version \(version.number), \(version.summary)")
  }

  @ViewBuilder private var summaryButton: some View {
    if case .translation = version.edit {
      Text(version.summary).foregroundStyle(.secondary)
    } else if version.changes.isEmpty {
      Text("✓ " + version.summary).foregroundStyle(.secondary)
        .accessibilityLabel(version.summary)
    } else {
      Button((showsChanges ? "▾ " : "▸ ") + version.summary) { showsChanges.toggle() }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        // VoiceOver hears the state in words instead of the triangle.
        .accessibilityLabel(version.summary)
        .accessibilityValue(showsChanges ? "Expanded" : "Collapsed")
        .accessibilityHint("Shows the list of changes")
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
}

/// A row reads as one element with its Never Change items as VoiceOver actions and in its context
/// menu; Reject follows it, so Tab reaches it without a mouse (05 §2.4, §7).
private struct ChangeList: View {
  let version: Version
  let canReject: Bool
  let actions: VersionCard.Actions

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(version.changes) { change in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          description(change)
          Spacer()
          if canReject {
            rejectButton(change)
          }
        }
        // The whole row, gaps included, opens the menu.
        .contentShape(Rectangle())
        .contextMenu { neverChange(change) }
        .accessibilityElement(children: .contain)
      }
    }
  }

  private func description(_ change: Change) -> some View {
    let reason = version.reasons[change.id]
    return HStack(alignment: .firstTextBaseline, spacing: 8) {
      // The shape tells error from style; green and blue on white fall below 3:1.
      Text(reason?.category == .style ? "◇" : "●")
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        Text("\(change.words[0]) → \(change.words[1])").font(
          .system(.body, design: .monospaced))
        if let reason { Text(reason.reason).foregroundStyle(.secondary) }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isStaticText)
    .accessibilityLabel(change.spoken(reason: reason))
    .accessibilityActions { neverChange(change) }
  }

  private func rejectButton(_ change: Change) -> some View {
    Button("Reject", systemImage: "xmark") { actions.reject(change) }
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .help("Reject this change")
  }

  /// Only the latest version's changes can be rejected or kept with the dictionary.
  @ViewBuilder private func neverChange(_ change: Change) -> some View {
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
/// solid for errors and dashed for style. Color is never the only signal, and every text keeps
/// 4.5:1 against its background. A translation is shown as plain text.
enum DiffText {
  private static let plain: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor,
  ]

  static func attributed(_ version: Version, layout: DiffLayout?) -> NSAttributedString {
    guard let layout else {
      return NSAttributedString(string: version.text, attributes: plain)
    }
    let result = NSMutableAttributedString()
    for piece in layout.pieces {
      result.append(NSAttributedString(string: piece.text, attributes: attributes(piece, version)))
    }
    return result
  }

  /// Removed words in the label color at 60%: 5.7:1 on the card, where the system's secondary
  /// label color gives 3.95:1 in the light theme.
  private static func attributes(_ piece: DiffLayout.Piece, _ version: Version)
    -> [NSAttributedString.Key: Any]
  {
    var attributes = plain
    switch piece.kind {
    case .same, .gap:
      break
    case .removed:
      attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
      attributes[.foregroundColor] = NSColor.labelColor.withAlphaComponent(0.6)
    case .added(let change):
      let isStyle = version.reasons[change.id]?.category == .style
      attributes[.underlineStyle] =
        isStyle
        ? NSUnderlineStyle([.single, .patternDash]).rawValue : NSUnderlineStyle.single.rawValue
      attributes[.backgroundColor] =
        isStyle
        ? NSColor.systemBlue.withAlphaComponent(0.15) : NSColor.systemGreen.withAlphaComponent(0.2)
    }
    return attributes
  }
}
