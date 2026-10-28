// The clipboard: the fallback for reading text and the only way the result goes back.
// See docs/specs/02 C2, C3.

import AppKit
import CoreGraphics

enum Clipboard {
  static var string: String? { NSPasteboard.general.string(forType: .string) }

  static func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }

  /// Presses ⌘C in the front app and returns what it copied; the clipboard is restored.
  static func copySelection() async -> String? {
    let saved = Snapshot()
    let before = NSPasteboard.general.changeCount
    press(key: 0x08)  // C
    for _ in 0..<10 where NSPasteboard.general.changeCount == before {
      try? await Task.sleep(for: .milliseconds(30))
    }
    let copied = NSPasteboard.general.changeCount == before ? nil : string
    saved.restore()
    return copied
  }

  /// ⌘A in the front app.
  static func selectAll() {
    press(key: 0x00)  // A
  }

  private static func press(key: CGKeyCode) {
    let source = CGEventSource(stateID: .combinedSessionState)
    for isDown in [true, false] {
      let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
      event?.flags = .maskCommand
      event?.post(tap: .cghidEventTap)
    }
  }

  /// Every item and type on the clipboard, to put back after a simulated copy.
  private struct Snapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init() {
      items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
        Dictionary(
          uniqueKeysWithValues: item.types.compactMap { type in
            item.data(forType: type).map { (type, $0) }
          })
      }
    }

    func restore() {
      NSPasteboard.general.clearContents()
      let restored = items.map { types in
        let item = NSPasteboardItem()
        for (type, data) in types { item.setData(data, forType: type) }
        return item
      }
      NSPasteboard.general.writeObjects(restored)
    }
  }
}
