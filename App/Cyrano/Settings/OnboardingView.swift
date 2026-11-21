// The first setup: a welcome, sign in, Accessibility, context from the window, shortcut. It shows
// until Done is pressed once. See docs/specs/05-ui.md §1.

import CyranoCore
import KeyboardShortcuts
import SwiftUI

struct OnboardingView: View {
  let app: AppModel
  /// The height the form needs to show everything; the window follows it (05 §1).
  let fitHeight: (CGFloat) -> Void
  @AppStorage("showInMenuBar") private var showInMenuBar = true

  var body: some View {
    Form {
      welcome
      signIn
      Section("2. Accessibility") {
        Text(
          "Cyrano reads the text in the field you're typing in, so you don't have to copy it."
        )
        PermissionStatus.accessibility
      }
      Section("3. Context from the window") {
        ReadContextToggle(app: app)
        // Asked only for those who want it; otherwise 📷 asks on its first press.
        if app.readsContext {
          PermissionStatus.screenRecording
        }
      }
      Section("4. Shortcut") {
        KeyboardShortcuts.Recorder("Check text", name: .checkText)
        Text("Select text or put the cursor in a text field, then press the shortcut.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Toggle("Show in menu bar", isOn: $showInMenuBar)
      }
      done
    }
    .formStyle(.grouped)
    .frame(width: 520)
    // Sections grow and shrink with the state: signed in or not, permissions, the toggle.
    .onScrollGeometryChange(for: CGFloat.self) { geometry in
      geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
    } action: { _, height in
      fitHeight(height)
    }
  }

  private var welcome: some View {
    Section {
      Text("Welcome to Cyrano")
        .font(.title2)
        .accessibilityAddTraits(.isHeader)
      Text(
        "Cyrano checks what you write in any app with your ChatGPT plan. Set up what it needs.")
    }
  }

  /// Pressed once, Done ends onboarding for good (05 §1).
  private var done: some View {
    HStack {
      Text("You can change all of this later in Settings.")
        .font(.caption)
        .foregroundStyle(.secondary)
      Spacer()
      Button("Done") { app.finishOnboarding() }
        .keyboardShortcut(.defaultAction)
    }
  }

  private var signIn: some View {
    Section("1. Sign in") {
      Text("Cyrano uses your ChatGPT Plus or Pro plan to check your messages.")
      if let account = app.account {
        Label("Signed in as \(account.name)", systemImage: "checkmark.circle.fill")
      } else {
        SignInControls(app: app)
      }
      Text("Your text is sent to OpenAI only when you run a check. It is not stored.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}
