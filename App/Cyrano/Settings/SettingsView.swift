// Settings: General, Style, Account. See docs/specs/05-ui.md §5.

import ApplicationServices
import CoreGraphics
import CyranoCore
import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
  let app: AppModel

  var body: some View {
    TabView {
      Tab("General", systemImage: "gearshape") { GeneralPane(app: app) }
      Tab("Style", systemImage: "textformat") { StylePane(app: app) }
      Tab("Account", systemImage: "person.crop.circle") { AccountPane(app: app) }
    }
    .frame(width: 520)
  }
}

private struct GeneralPane: View {
  @Bindable var app: AppModel
  @AppStorage("showInMenuBar") private var showInMenuBar = true

  var body: some View {
    Form {
      Picker("Model", selection: $app.model) {
        ForEach(Model.allCases, id: \.self) { Text($0.title).tag($0) }
      }
      Toggle("Show in menu bar", isOn: $showInMenuBar)
      Toggle(isOn: $app.readsContext) {
        Text("Read context from the window")
        Text("A screenshot of the window goes to OpenAI to find who you're replying to.")
      }
      Section("Shortcut") {
        KeyboardShortcuts.Recorder("Check text", name: .checkText)
      }
      Section("Permissions") {
        PermissionStatus.accessibility
        PermissionStatus.screenRecording
        Text("Screen Recording is used to read who you're replying to and for the camera button.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

private struct StylePane: View {
  @Bindable var app: AppModel

  var body: some View {
    Form {
      Section("Custom instructions") {
        TextEditor(text: $app.customInstructions)
          .font(.body)
          .frame(height: 120)
        Text("Added to every check, one rule per line. Changes apply to the next check.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

private struct AccountPane: View {
  let app: AppModel

  var body: some View {
    Form {
      if let account = app.account {
        LabeledContent("Signed in as", value: account.email ?? "ChatGPT user")
        Button("Sign Out") { Task { await app.signOut() } }
      } else {
        SignInControls(app: app)
      }
    }
    .formStyle(.grouped)
  }
}

/// «Continue with ChatGPT» and the states of signing in. See docs/specs/05-ui.md §1.
struct SignInControls: View {
  let app: AppModel
  var then: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch app.signIn {
      case .waiting:
        HStack {
          ProgressView().controlSize(.small)
          Text("Waiting for the browser…")
          Button("Cancel") { app.cancelSignIn() }
        }
      case .idle, .failed:
        Button("Continue with ChatGPT") { app.signInWithChatGPT(then: then) }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
      }
      if case .failed(let message) = app.signIn {
        Text(message).foregroundStyle(.red)
      }
    }
  }
}

/// Polls the Accessibility permission once a second until it is granted.
/// One system permission: granted, or a button to its pane in System Settings.
struct PermissionStatus: View {
  static let accessibility = PermissionStatus(
    title: "Accessibility", pane: "Privacy_Accessibility", isGranted: { AXIsProcessTrusted() })
  /// For 📷 in the context and for reading text from a screenshot when nothing else works.
  static let screenRecording = PermissionStatus(
    title: "Screen Recording", pane: "Privacy_ScreenCapture",
    isGranted: { CGPreflightScreenCaptureAccess() },
    // macOS lists an app in Screen Recording only after it asked for access once.
    request: { CGRequestScreenCaptureAccess() })

  let title: String
  let pane: String
  let isGranted: () -> Bool
  var request: () -> Void = {}
  @State private var granted = false

  func openSettings() {
    let url = "x-apple.systempreferences:com.apple.preference.security?\(pane)"
    if let url = URL(string: url) { NSWorkspace.shared.open(url) }
  }

  var body: some View {
    HStack {
      Text(title)
      Spacer()
      if granted {
        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
      } else {
        Button("Open System Settings…") {
          request()
          openSettings()
        }
      }
    }
    .task {
      granted = isGranted()
      while !granted, !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
        granted = isGranted()
      }
    }
  }
}
