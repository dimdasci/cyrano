// An ordinary app in the Dock, with its menus, Settings, the optional menu bar icon and the global
// shortcut. See docs/specs/02-tech-decisions.md T5, docs/specs/05-ui.md §4.

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
    // With no window open, macOS would count Cyrano as quit and may end it, taking ⌥⌘G with it;
    // a Dock click then reaches no one (02 T5).
    ProcessInfo.processInfo.disableAutomaticTermination("Cyrano waits for ⌥⌘G with no window open")
    // Hints in the panel stay until closed or followed (05 §1).
    try? Tips.configure([.displayFrequency(.immediate)])
    KeyboardShortcuts.onKeyUp(for: .checkText) { [app] in
      app.checkFocusedText()
    }
    Task {
      await app.start()
      if let window = app.setup.windowAtLaunch { app.open(window) }
    }
  }

  /// A click on the Dock icon and launching Cyrano again come here alike (05 §4).
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    app.reopen()
    return false
  }

  /// Closing the last window leaves Cyrano running, for the shortcut and the Dock; ⌘Q quits it.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}

extension KeyboardShortcuts.Name {
  static let checkText = Self("checkText", initial: .init(.g, modifiers: [.option, .command]))
}

private struct MenuContent: View {
  let app: AppModel

  var body: some View {
    Button("Check Text…") { app.checkText() }
    Button("Check Clipboard") { app.checkClipboard() }
    Divider()
    if let account = app.account {
      Text("Signed in as \(account.name)")
    } else {
      Button("Sign In with ChatGPT…") { app.showSettings(.account) }
    }
    if !AXIsProcessTrusted() {
      Button("Grant Accessibility…") { app.showSettings(.general) }
    }
    Divider()
    Button("About Cyrano") { app.showAbout() }
    // A click on the menu bar icon doesn't activate Cyrano: Settings comes forward on its own.
    Button("Settings…") { app.showSettings() }
      .keyboardShortcut(",")
    Button("Quit Cyrano") { NSApp.terminate(nil) }
      .keyboardShortcut("q")
  }
}
