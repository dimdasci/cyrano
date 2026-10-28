// First launch: sign in, Accessibility, shortcut. See docs/specs/05-ui.md §1.

import CyranoCore
import KeyboardShortcuts
import SwiftUI

struct OnboardingView: View {
  let app: AppModel
  @AppStorage("showInMenuBar") private var showInMenuBar = true

  var body: some View {
    Form {
      Section("1. Sign in") {
        Text("Cyrano uses your ChatGPT Plus or Pro plan to check your messages.")
        if let account = app.account {
          Label(
            "Signed in as \(account.email ?? "ChatGPT user")", systemImage: "checkmark.circle.fill")
        } else {
          SignInControls(app: app)
        }
        Text("Your text is sent to OpenAI only when you run a check. It is not stored.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("2. Accessibility") {
        Text(
          "Cyrano reads the text in the field you're typing in, so you don't have to copy it."
        )
        PermissionStatus.accessibility
      }
      Section("3. Shortcut") {
        KeyboardShortcuts.Recorder("Check text", name: .checkText)
        Text("Select text or put the cursor in a text field, then press the shortcut.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Toggle("Show in menu bar", isOn: $showInMenuBar)
      }
      HStack {
        Spacer()
        Button("Done") { app.closeOnboarding() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 520, minHeight: 440)
  }
}
