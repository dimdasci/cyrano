import AppKit
import SwiftUI

/// Cyrano's own windows: one per id, brought to the front when shown again.
/// A closed window is released, so showing it again starts afresh.
final class WindowPresenter: NSObject, NSWindowDelegate {
  private var windows: [String: NSWindow] = [:]

  func show(id: String, title: String, size: CGSize, @ViewBuilder content: () -> some View) {
    AppPresence.activate()
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

  /// Makes the window as tall as its content, up to the screen's visible height, with the top
  /// edge in place; beyond that the content scrolls. On the next turn of the event loop: resizing
  /// a window during its own layout makes AppKit lay it out again.
  func fit(id: String, contentHeight: CGFloat) {
    DispatchQueue.main.async { [weak self] in
      guard let window = self?.windows[id], let screen = window.screen ?? NSScreen.main else {
        return
      }
      let wanted = window.frameRect(
        forContentRect: CGRect(
          origin: .zero, size: CGSize(width: 0, height: contentHeight.rounded(.up)))
      ).height
      let height = min(wanted, screen.visibleFrame.height)
      guard abs(height - window.frame.height) >= 1 else { return }
      var frame = window.frame
      frame.origin.y = max(frame.maxY - height, screen.visibleFrame.minY)
      frame.size.height = height
      window.setFrame(frame, display: true)
    }
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
