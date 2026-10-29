// Card text the user can select, with a dictionary item at the top of its context menu. SwiftUI
// Text doesn't tell what is selected, so this is an NSTextView. See docs/specs/05-ui.md §2.4.

import AppKit
import SwiftUI

struct SelectableText: NSViewRepresentable {
  let text: NSAttributedString
  /// The item for the selected text, if it makes a term.
  let menuItem: (String) -> DictionaryItem?

  func makeNSView(context: Context) -> MenuTextView {
    MenuTextView()
  }

  func updateNSView(_ view: MenuTextView, context: Context) {
    if view.textStorage?.isEqual(to: text) != true {
      view.textStorage?.setAttributedString(text)
    }
    view.menuItem = menuItem
  }

  /// As tall as the text laid out at the offered width.
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: MenuTextView, context: Context)
    -> CGSize?
  {
    guard let width = proposal.width, width.isFinite else { return nil }
    let storage = NSTextStorage(attributedString: text)
    let layout = NSLayoutManager()
    let container = NSTextContainer(
      size: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    layout.addTextContainer(container)
    storage.addLayoutManager(layout)
    layout.ensureLayout(for: container)
    return CGSize(width: width, height: ceil(layout.usedRect(for: container).height))
  }
}

final class MenuTextView: NSTextView {
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

  override func menu(for event: NSEvent) -> NSMenu? {
    let menu = super.menu(for: event) ?? NSMenu()
    let selection = (string as NSString).substring(with: selectedRange())
    guard let item = menuItem?(selection) else { return menu }
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
