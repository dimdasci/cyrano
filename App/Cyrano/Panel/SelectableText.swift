// Card text the user can select or edit, with a dictionary item at the top of its context menu
// and among its VoiceOver actions. SwiftUI Text and TextEditor don't tell what is selected, so
// this is an NSTextView. See docs/specs/05-ui.md §2.4, §7.

import AppKit
import CyranoCore
import SwiftUI

/// A version's text with its diff. VoiceOver reads the version itself, without removed words.
struct SelectableText: NSViewRepresentable {
  let text: NSAttributedString
  let layout: DiffLayout?
  let label: String
  /// The item for the selected text, if it makes a term.
  let menuItem: (String) -> DictionaryItem?

  func makeNSView(context: Context) -> DiffTextView {
    DiffTextView()
  }

  func updateNSView(_ view: DiffTextView, context: Context) {
    if view.textStorage?.isEqual(to: text) != true {
      view.textStorage?.setAttributedString(text)
    }
    view.layout = layout
    view.menuItem = menuItem
    view.setAccessibilityLabel(label)
  }

  /// As tall as the text laid out at the offered width.
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: DiffTextView, context: Context)
    -> CGSize?
  {
    guard let width = proposal.width, width.isFinite else { return nil }
    return CGSize(width: width, height: MenuTextView.height(of: text, width: width))
  }
}

class MenuTextView: NSTextView {
  var menuItem: ((String) -> DictionaryItem?)?

  /// TextKit 1, laid out the same way as `sizeThatFits` measures it.
  init() {
    let storage = NSTextStorage()
    let layout = NSLayoutManager()
    let container = NSTextContainer(
      size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    container.widthTracksTextView = true
    container.lineFragmentPadding = 0
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    super.init(frame: .zero, textContainer: container)
    isEditable = false
    isSelectable = true
    drawsBackground = false
    textContainerInset = .zero
    isVerticallyResizable = false
    isHorizontallyResizable = false
  }

  required init?(coder: NSCoder) { nil }

  /// The height of the text laid out at a width, the same way this view lays it out.
  static func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
    let storage = NSTextStorage(attributedString: text)
    let layout = NSLayoutManager()
    let container = NSTextContainer(
      size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    layout.ensureLayout(for: container)
    return ceil(layout.usedRect(for: container).height)
  }

  /// The item for the current selection, if it makes a term.
  private var selectionItem: DictionaryItem? {
    menuItem?((string as NSString).substring(with: selectedRange()))
  }

  /// The text view's own menu (Cut, Copy, Paste, Spelling…) with the item on top.
  override func menu(for event: NSEvent) -> NSMenu? {
    let menu = super.menu(for: event) ?? NSMenu()
    guard let item = selectionItem else { return menu }
    let action = MenuAction(item.perform)
    let menuItem = NSMenuItem(
      title: item.title, action: #selector(MenuAction.run), keyEquivalent: "")
    menuItem.target = action
    // The target is weak; the item keeps the action alive while the menu is open.
    menuItem.representedObject = action
    menu.insertItem(.separator(), at: 0)
    menu.insertItem(menuItem, at: 0)
    return menu
  }

  /// The same item as in the menu, as a VoiceOver action on the selection (05 §7).
  override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
    let own = super.accessibilityCustomActions() ?? []
    guard let item = selectionItem else { return own }
    let action = NSAccessibilityCustomAction(name: item.title) {
      item.perform()
      return true
    }
    return [action] + own
  }

  /// Tab leaves the text for the next control: a tab character means nothing in the panel's
  /// texts, and the keyboard would be stuck here (05 §7).
  override func insertTab(_ sender: Any?) {
    window?.selectNextKeyView(self)
  }

  override func insertBacktab(_ sender: Any?) {
    window?.selectPreviousKeyView(self)
  }

  /// Esc closes the panel from its texts too; a text view would offer word completions instead.
  override func cancelOperation(_ sender: Any?) {
    window?.cancelOperation(sender)
  }

  /// The text takes the keyboard once it is in the window.
  var takesFocus = false

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard takesFocus, let window else { return }
    takesFocus = false
    window.makeFirstResponder(self)
  }

  /// Edit → Paste with an image on the clipboard adds it to Context, wherever the cursor is in
  /// the panel; text pastes as usual (05 §2.3a).
  override func paste(_ sender: Any?) {
    if let window = window as? ProofreadingWindow, window.pastesImages {
      window.paste(sender)
    } else {
      super.paste(sender)
    }
  }

  override func validateMenuItem(_ item: NSMenuItem) -> Bool {
    if item.action == #selector(paste(_:)), (window as? ProofreadingWindow)?.pastesImages == true {
      return true
    }
    return super.validateMenuItem(item)
  }
}

private final class MenuAction: NSObject {
  private let perform: () -> Void

  init(_ perform: @escaping () -> Void) {
    self.perform = perform
  }

  @objc func run() {
    perform()
  }
}
