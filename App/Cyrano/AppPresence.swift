// Cyrano in the menu bar, and in the Dock while a window of its own is open. See
// docs/specs/02-tech-decisions.md T5.

import AppKit

/// A menu bar agent with no Dock icon and no menus of its own. While a window of its own is open
/// (the panel, Settings, About, onboarding), it's a regular app: a Dock icon, a place in ⌘Tab and
/// Mission Control, and its menus in the menu bar.
enum AppPresence {
  /// Brings Cyrano forward as a regular app, before one of its windows shows.
  static func activate() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate()
  }

  /// After the last window closes, Cyrano goes back to the menu bar only.
  static func start() {
    NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: nil, queue: .main
    ) { _ in
      // The closing window is still on screen until this turn of the event loop ends.
      DispatchQueue.main.async {
        guard !NSApp.windows.contains(where: isOpen) else { return }
        NSApp.setActivationPolicy(.accessory)
      }
    }
  }

  /// A window the user sees as one: titled, on screen or in the Dock.
  private static func isOpen(_ window: NSWindow) -> Bool {
    window.styleMask.contains(.titled) && (window.isVisible || window.isMiniaturized)
  }
}
