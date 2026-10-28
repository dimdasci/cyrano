import AppKit
import CyranoCore
import SwiftUI

/// Ordinary windows of a menu bar agent: one per id, brought to the front when shown again.
final class WindowPresenter {
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
    window.center()
    windows[id] = window
    window.makeKeyAndOrderFront(nil)
  }

  func close(id: String) {
    windows[id]?.close()
    windows[id] = nil
  }
}

enum AboutCredits {
  static func text(model: Model) -> NSAttributedString {
    let lines = [
      "Author: Dim Kharitonov",
      "License: MIT",
      "Source: github.com/dimdasci/cyrano",
      "Docs: dimdasci.github.io/cyrano",
      "Model: \(model.rawValue)",
    ]
    return NSAttributedString(
      string: lines.joined(separator: "\n"),
      attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor])
  }
}
