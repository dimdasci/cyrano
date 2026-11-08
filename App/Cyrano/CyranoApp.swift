// Menu bar agent: the menu, Settings, the menus while a window is open and the global shortcut.
// See docs/specs/05-ui.md §4.

import AppKit
import CyranoCore
import KeyboardShortcuts
import SwiftUI
import TipKit

@main
struct CyranoApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @AppStorage("showInMenuBar") private var showInMenuBar = true

  var body: some Scene {
    MenuBarExtra("Cyrano", systemImage: "text.badge.checkmark", isInserted: $showInMenuBar) {
      MenuContent(app: delegate.app)
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsView(app: delegate.app)
    }
    // The standard menus, with the credits in About (05 §4).
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button("About Cyrano") { delegate.app.showAbout() }
      }
      PanelActionCommands(panel: delegate.app.panel)
      CommandGroup(replacing: .help) {
        Button("Cyrano Help") {
          if let docs = URL(string: "https://dimdasci.github.io/cyrano") {
            NSWorkspace.shared.open(docs)
          }
        }
      }
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  let app = AppModel()

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Hints in the panel stay until closed or followed (05 §1).
    try? Tips.configure([.displayFrequency(.immediate)])
    AppPresence.start()
    KeyboardShortcuts.onKeyUp(for: .checkText) { [app] in
      app.checkFocusedText()
    }
    Task {
      await app.start()
      if app.account == nil || !AXIsProcessTrusted() { app.showOnboarding() }
    }
  }

  /// With the menu bar icon hidden, launching the app again is the way back in.
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    app.showOnboarding()
    return true
  }
}

extension KeyboardShortcuts.Name {
  static let checkText = Self("checkText", initial: .init(.g, modifiers: [.option, .command]))
}

private struct MenuContent: View {
  let app: AppModel
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Button("Check Text…") { app.checkText() }
    Button("Check Clipboard") { app.checkClipboard() }
    Divider()
    if let account = app.account {
      Text("Signed in as \(account.email ?? "ChatGPT user")")
    } else {
      Button("Sign In with ChatGPT…") { app.showOnboarding() }
    }
    if !AXIsProcessTrusted() {
      Button("Grant Accessibility…") { app.showOnboarding() }
    }
    Divider()
    Button("About Cyrano") { app.showAbout() }
    // SettingsLink doesn't activate a menu bar agent, so a Settings window left behind another app
    // would stay there.
    Button("Settings…") {
      AppPresence.activate()
      openSettings()
    }
    .keyboardShortcut(",")
    Button("Quit Cyrano") { NSApp.terminate(nil) }
      .keyboardShortcut("q")
  }
}
