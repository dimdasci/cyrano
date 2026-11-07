// Settings: General, Style, Dictionary, Prompts, Account. See docs/specs/05-ui.md §5.

import ApplicationServices
import CoreGraphics
import CyranoCore
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
  let app: AppModel

  var body: some View {
    TabView {
      Tab("General", systemImage: "gearshape") { GeneralPane(app: app) }
      Tab("Style", systemImage: "textformat") { StylePane(app: app) }
      Tab("Dictionary", systemImage: "character.book.closed") {
        DictionaryPane(dictionary: app.dictionary)
      }
      Tab("Prompts", systemImage: "text.bubble") { PromptsPane(prompts: app.prompts) }
      Tab("Account", systemImage: "person.crop.circle") { AccountPane(app: app) }
    }
    // Wide enough for the five columns of Style → Per-app defaults.
    .frame(width: 600)
  }
}

private struct GeneralPane: View {
  @Bindable var app: AppModel
  @AppStorage("showInMenuBar") private var showInMenuBar = true

  var body: some View {
    Form {
      Toggle("Show in menu bar", isOn: $showInMenuBar)
      LaunchAtLogin()
      ReadContextToggle(app: app)
      Section("Models") {
        modelPicker("Read context", "Describes the conversation from a screenshot", \.context)
        modelPicker("Proofreading", "Checks and the dialog", \.proofreading)
        modelPicker("Explanations", "Reasons for each change", \.explanations)
      }
      Section("Shortcut") {
        KeyboardShortcuts.Recorder("Check text", name: .checkText)
      }
      Section("Permissions") {
        PermissionStatus.accessibility
        PermissionStatus.screenRecording
        Text("Screen Recording is used to read who you're writing to and for the camera button.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }

  private func modelPicker(
    _ title: String, _ detail: String, _ operation: WritableKeyPath<ModelChoice, Model>
  ) -> some View {
    Picker(selection: $app.models[dynamicMember: operation]) {
      ForEach(Model.allCases, id: \.self) { Text($0.rawValue).tag($0) }
    } label: {
      Text(title)
      Text(detail)
    }
  }
}

/// The same choice as in onboarding (05 §1): read who the user replies to from the window.
struct ReadContextToggle: View {
  @Bindable var app: AppModel

  var body: some View {
    Toggle(isOn: $app.readsContext) {
      Text("Read context from the window")
      Text(
        "A screenshot of the window goes to OpenAI to find who you're writing to, what about "
          + "and in which language.")
    }
  }
}

/// The login item is the system's: its status is read back, not stored.
private struct LaunchAtLogin: View {
  @State private var status = SMAppService.mainApp.status
  @State private var failure: String?

  var body: some View {
    Toggle(
      "Launch at login",
      isOn: Binding(get: { status != .notRegistered && status != .notFound }, set: change))
    if status == .requiresApproval {
      HStack {
        Text("Allow Cyrano in Login Items to start it at login.").foregroundStyle(.secondary)
        Spacer()
        Button("Open System Settings…") { SMAppService.openSystemSettingsLoginItems() }
      }
    }
    if let failure {
      Text(failure).foregroundStyle(.secondary)
    }
  }

  private func change(_ launches: Bool) {
    do {
      if launches {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      failure = nil
    } catch {
      failure = "Couldn't change the login item: \(error.localizedDescription)"
    }
    status = SMAppService.mainApp.status
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
  /// For 📷 in the context and for reading who the user replies to from the window.
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
