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
    let reason = version.reason(for: change)
    let ascender = DiffText.changeFont.ascender
    return HStack(alignment: .firstTextBaseline, spacing: 8) {
      // An ordinary list bullet: the line under the change tells error from style.
      Text("•").foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        MarkedText(text: DiffText.change(change, kind: version.kind(of: change)))
          // The bullet and Reject sit on the first line's baseline.
          .alignmentGuide(.firstTextBaseline) { _ in ascender }
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
}

/// Removed words struck through and dimmed; each change's whole block carries its mark (`ChangeMark`).
/// Every text keeps 4.5:1 against its background. A translation is shown as plain text.
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

  /// A change's removed words, the space and its added words carry its mark as one block. Removed
  /// words are struck through in the label color at 60%, where the system's secondary label color
  /// gives 3.95:1 on the light card.
  private static func attributes(_ piece: DiffLayout.Piece, _ version: Version)
    -> [NSAttributedString.Key: Any]
  {
    guard let change = piece.change else { return plain }
    let marked = plain.merging(ChangeMark.text(version.kind(of: change))) { $1 }
    guard case .removed = piece.kind else { return marked }
    return marked.merging([
      .strikethroughStyle: NSUnderlineStyle.single.rawValue,
      .foregroundColor: NSColor.labelColor.withAlphaComponent(0.6),
    ]) { $1 }
  }

  /// A row of the list of changes: `before → after` with the change's line under it.
  static let changeFont = NSFont.monospacedSystemFont(
    ofSize: NSFont.systemFontSize, weight: .regular)

  static func change(_ change: Change, kind: ChangeKind) -> NSAttributedString {
    let attributes: [NSAttributedString.Key: Any] = [
      .font: changeFont, .foregroundColor: NSColor.labelColor,
    ]
    return NSAttributedString(
      string: "\(change.words[0]) → \(change.words[1])",
      attributes: attributes.merging(ChangeMark.line(kind)) { $1 })
  }
}
