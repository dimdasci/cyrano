// ⌘V with an image on the clipboard adds it to the context, wherever the focus is in the window.
// The text fields would otherwise take the paste and drop the image. See docs/specs/05-ui.md §2.3a.

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct ImagePasteMonitor: NSViewRepresentable {
  let paste: ([Data]) -> Void

  func makeNSView(context: Context) -> MonitorView {
    MonitorView()
  }

  func updateNSView(_ view: MonitorView, context: Context) {
    view.paste = paste
  }

  final class MonitorView: NSView {
    var paste: ([Data]) -> Void = { _ in }
    private var monitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
      guard window != nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, event.window === self.window, Self.isPaste(event) else { return event }
        let images = ContextImages.fromPasteboard()
        guard !images.isEmpty else { return event }
        self.paste(images)
        return nil
      }
    }

    /// ⌘V in any layout: a Russian layout gives "м" for the V key, so the physical key counts too.
    private static func isPaste(_ event: NSEvent) -> Bool {
      // Caps Lock and the Fn key don't change the shortcut.
      event.modifierFlags.intersection([.command, .shift, .option, .control]) == .command
        && (event.charactersIgnoringModifiers == "v" || event.keyCode == UInt16(kVK_ANSI_V))
    }
  }
}
