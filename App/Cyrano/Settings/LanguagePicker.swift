// Settings → General → Language. See docs/specs/05-ui.md §5, §6.

import AppKit
import CyranoCore
import SwiftUI

/// The interface language: the system's or one of Cyrano's. It is the app's own `AppleLanguages`,
/// the value System Settings sets for one app, so a choice made there shows here too. macOS reads
/// it at launch: a new choice offers a relaunch instead of switching the open windows.
struct LanguagePicker: View {
  @State private var choice = Self.stored

  var body: some View {
    Picker("Language", selection: Binding(get: { choice }, set: store)) {
      ForEach(LanguageChoice.all, id: \.self) { choice in
        switch choice {
        case .system: Text("System").tag(choice)
        case .fixed(let language): Text(verbatim: language.ownName).tag(choice)
        }
      }
    }
    // Back from System Settings, where the same language can be set for Cyrano.
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in choice = Self.stored
    }
    if choice.needsRelaunch(running: .current, system: Self.system) {
      HStack {
        Text("Cyrano will use the new language after a relaunch.").foregroundStyle(.secondary)
        Spacer()
        Button("Relaunch", action: Self.relaunch)
      }
    }
  }

  private func store(_ choice: LanguageChoice) {
    if let languages = choice.appLanguages {
      UserDefaults.standard.set(languages, forKey: Self.key)
    } else {
      UserDefaults.standard.removeObject(forKey: Self.key)
    }
    self.choice = Self.stored
  }

  private static let key = "AppleLanguages"

  /// The app's own value, not a `-AppleLanguages` launch argument over it.
  private static var stored: LanguageChoice {
    let domain = Bundle.main.bundleIdentifier.flatMap(UserDefaults.standard.persistentDomain)
    return LanguageChoice(appLanguages: domain?[key] as? [String])
  }

  /// The languages of System Settings → General → Language & Region, without the app's own.
  private static var system: [String] {
    let value = CFPreferencesCopyValue(
      key as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser,
      kCFPreferencesAnyHost)
    return value as? [String] ?? []
  }

  /// Opens Cyrano again once this process has quit; a second copy would fight it for the hotkey.
  private static func relaunch() {
    let process = Process()
    process.executableURL = URL(filePath: "/bin/sh")
    process.arguments = [
      "-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; open \"$0\"",
      Bundle.main.bundlePath, String(ProcessInfo.processInfo.processIdentifier),
    ]
    do {
      try process.run()
      NSApp.terminate(nil)
    } catch {
      NSSound.beep()
    }
  }
}
