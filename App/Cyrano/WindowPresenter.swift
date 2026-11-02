import AppKit
import SwiftUI

/// Ordinary windows of a menu bar agent: one per id, brought to the front when shown again.
/// A closed window is released, so showing it again starts afresh.
final class WindowPresenter: NSObject, NSWindowDelegate {
  private var windows: [String: NSWindow] = [:]

  func show(id: String, title: String, size: CGSize, @ViewBuilder content: () -> some View) {
    NSApp.activate()
    if let window = windows[id] {
      window.makeKeyAndOrderFront(nil)
      return
    }
    let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
    window.title = title
    window.setContentSize(size)
    window.styleMask = [.titled, .closable, .resizable]
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()
    windows[id] = window
    window.makeKeyAndOrderFront(nil)
  }

  func close(id: String) {
    windows[id]?.close()
  }

  func windowWillClose(_ notification: Notification) {
    windows = windows.filter { $0.value !== notification.object as? NSWindow }
  }
}

enum AboutCredits {
  static var text: NSAttributedString {
    let lines = [
      "Author: Dim Kharitonov",
      "License: MIT",
      "Source: github.com/dimdasci/cyrano",
      "Docs: dimdasci.github.io/cyrano",
    ]
    return NSAttributedString(
      string: lines.joined(separator: "\n"),
      attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
  }
}
