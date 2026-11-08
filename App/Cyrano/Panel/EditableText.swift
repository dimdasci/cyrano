// The panel's editable text: Text to check, Context and the dialog field. All three are the same
// text view as the card text, so Tab leaves them, Esc closes the panel and an image pasted into
// them goes to Context. See docs/specs/05-ui.md §2.3a, §2.4, §2.7.

import AppKit
import SwiftUI

/// Text to check: plain text the user edits before the first check, with Never Change on top of
/// the text field's own menu. As tall as its text, inside the feed's scroll view.
struct EditableText: NSViewRepresentable {
  @Binding var text: String
  /// A running check freezes the text and dims it, as a disabled field. Nothing can be
  /// selected, so no menu is open when the first version replaces this view: a menu whose view
  /// goes away never ends tracking, and the global hot key stays paused.
  let isEditable: Bool
  /// The item for the selected text, if it makes a term.
  let menuItem: (String) -> DictionaryItem?

  static let font = NSFont.systemFont(ofSize: 14)
  static let minHeight: CGFloat = 120
  static let placeholder = "Select text in any app and press ⌥⌘G, or type or paste it here"

  func makeCoordinator() -> TextBinding {
    TextBinding(text: $text)
  }

  func makeNSView(context: Context) -> MenuTextView {
    let view = MenuTextView.editable(
      text: text, font: Self.font, label: "Text to check", placeholder: Self.placeholder)
    view.delegate = context.coordinator
    // Nothing was captured: the cursor waits here for typing or pasting.
    view.takesFocus = text.isEmpty
    return view
  }

  func updateNSView(_ view: MenuTextView, context: Context) {
    context.coordinator.text = $text
    if view.string != text { view.string = text }
    view.isEditable = isEditable
    view.isSelectable = isEditable
    view.textColor = isEditable ? .labelColor : .secondaryLabelColor
    view.menuItem = menuItem
  }

  /// As tall as the text, but not shorter than a few lines to type into.
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: MenuTextView, context: Context)
    -> CGSize?
  {
    guard let width = proposal.width, width.isFinite else { return nil }
    let laidOut = NSAttributedString(string: text, attributes: [.font: Self.font])
    let height = MenuTextView.height(of: laidOut, width: width)
    return CGSize(width: width, height: max(height, Self.minHeight))
  }
}

/// Context and the dialog field: as tall as SwiftUI makes it, and the text scrolls inside.
struct FieldText: NSViewRepresentable {
  @Binding var text: String
  let label: String
  var placeholder: String?
  /// The field takes the keyboard when it appears.
  var takesFocus = false

  func makeCoordinator() -> TextBinding {
    TextBinding(text: $text)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let view = MenuTextView.editable(
      text: text, font: .systemFont(ofSize: NSFont.systemFontSize), label: label,
      placeholder: placeholder)
    view.delegate = context.coordinator
    view.takesFocus = takesFocus
    view.drawsBackground = true
    view.backgroundColor = .textBackgroundColor
    // The text grows down from the top and scrolls in the field.
    view.isVerticallyResizable = true
    view.autoresizingMask = [.width]
    view.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    let scroll = NSScrollView()
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true
    scroll.documentView = view
    // VoiceOver goes straight to the text, which carries the label.
    scroll.setAccessibilityElement(false)
    context.coordinator.view = view
    return scroll
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.text = $text
    if let view = context.coordinator.view, view.string != text { view.string = text }
  }
}

/// Keeps the SwiftUI text in step with the text view.
final class TextBinding: NSObject, NSTextViewDelegate {
  var text: Binding<String>
  weak var view: NSTextView?

  init(text: Binding<String>) {
    self.text = text
  }

  func textDidChange(_ notification: Notification) {
    guard let view = notification.object as? NSTextView else { return }
    text.wrappedValue = view.string
  }
}

extension MenuTextView {
  fileprivate static func editable(
    text: String, font: NSFont, label: String, placeholder: String?
  ) -> MenuTextView {
    let view = MenuTextView()
    view.isEditable = true
    view.isRichText = false
    view.allowsUndo = true
    view.font = font
    view.string = text
    view.setAccessibilityLabel(label)
    if let placeholder { view.setAccessibilityPlaceholderValue(placeholder) }
    return view
  }
}
