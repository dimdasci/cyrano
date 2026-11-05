// Text to check: plain text the user edits before the first check, with Never Change on top of
// the text field's own menu. See docs/specs/05-ui.md §2.4.

import AppKit
import SwiftUI

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

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> MenuTextView {
    let view = MenuTextView()
    view.isRichText = false
    view.allowsUndo = true
    view.font = Self.font
    view.string = text
    view.delegate = context.coordinator
    // Nothing was captured: the cursor waits here for typing or pasting.
    if text.isEmpty {
      DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
    }
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

  final class Coordinator: NSObject, NSTextViewDelegate {
    var text: Binding<String>

    init(text: Binding<String>) {
      self.text = text
    }

    func textDidChange(_ notification: Notification) {
      guard let view = notification.object as? NSTextView else { return }
      text.wrappedValue = view.string
    }
  }
}
