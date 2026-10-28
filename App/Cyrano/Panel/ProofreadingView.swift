// Panel layout: header, context, feed, composer, status. See docs/specs/05-ui.md §2.2.

import ApplicationServices
import CyranoCore
import SwiftUI
import UniformTypeIdentifiers

struct ProofreadingView: View {
  let model: PanelModel

  var body: some View {
    switch model.content {
    case .nothingToCheck:
      NothingToCheckView(app: model.app)
    case .readingScreen:
      ProgressView("Reading the text from the window…")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .session(let session, let captured):
      SessionView(model: model, session: session, captured: captured)
    }
  }
}

struct SessionView: View {
  let model: PanelModel
  @Bindable var session: ProofreadingSession
  let captured: CapturedText

  var body: some View {
    VStack(spacing: 0) {
      PanelHeader(session: session)
        .onChange(of: session.options) { model.optionsChanged(session, for: captured) }
      Divider()
      ContextBar(model: model, session: session)
      Divider()
      FeedView(model: model, session: session)
      Divider()
      Composer(session: session)
      StatusLine(session: session, message: model.status)
    }
    .frame(minWidth: 480, minHeight: 360)
    .background(ImagePasteMonitor { session.images += $0 })
    .onDrop(of: [.image, .fileURL], isTargeted: nil) { providers in
      Task { session.images += await ContextImages.load(providers) }
      return true
    }
    // Only the flag: the activity itself changes on every streamed delta.
    .onChange(of: session.activity == .failed(.notSignedIn)) { _, signedOut in
      if signedOut { model.app.markSignedOut() }
    }
  }
}

private struct PanelHeader: View {
  @Bindable var session: ProofreadingSession

  var body: some View {
    HStack(spacing: 6) {
      popUp("Context type", $session.options.textType, TextType.allCases, \.title)
      popUp("Tone", $session.options.tone, Tone.allCases, \.title)
      popUp("Level", $session.options.level, Level.allCases, \.title)
      if !AXIsProcessTrusted() {
        Image(systemName: "exclamationmark.triangle")
          .help("Grant Accessibility to read text directly")
          .accessibilityLabel("Accessibility not granted")
      }
      Spacer(minLength: 6)
      popUp(
        "Output language", $session.options.language, OutputLanguage.allCases, \.title,
        label: session.options.language == .sameAsText ? "Auto" : nil, icon: "globe"
      )
      .help("Language of the corrected text")
    }
    // Small pop-ups fit the longest values ("Professional", "Errors Only", "English (UK)") into
    // the narrowest panel.
    .controlSize(.small)
    .disabled(session.isBusy)
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
  }

  /// A pop-up as wide as its current value, not as its longest option.
  private func popUp<Value: Hashable>(
    _ name: String, _ selection: Binding<Value>, _ values: [Value],
    _ title: KeyPath<Value, String>, label: String? = nil, icon: String? = nil
  ) -> some View {
    Menu {
      Picker(name, selection: selection) {
        ForEach(values, id: \.self) { Text($0[keyPath: title]).tag($0) }
      }
      .pickerStyle(.inline)
      .labelsHidden()
    } label: {
      let text = label ?? selection.wrappedValue[keyPath: title]
      if let icon { Label(text, systemImage: icon) } else { Text(text) }
    }
    .fixedSize()
    .accessibilityLabel(name)
  }
}

private struct Composer: View {
  let session: ProofreadingSession
  @State private var draft = ""

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      TextEditor(text: $draft)
        .font(.body)
        .frame(height: 44)
        .overlay(alignment: .topLeading) {
          if draft.isEmpty {
            Text("Ask or tell what to change… (any language)")
              .foregroundStyle(.tertiary)
              .padding(.leading, 5)
              .allowsHitTesting(false)
          }
        }
      Button(action: send) {
        Image(systemName: "arrow.up.circle.fill").font(.title2)
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.return, modifiers: .command)
      // The dialog continues a check; before the first one there is nothing to talk about.
      .disabled(
        draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy
          || session.versions.isEmpty
      )
      .accessibilityLabel("Send")
      .help("Send (⌘↩)")
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
  }

  private func send() {
    let message = draft
    draft = ""
    Task { await session.send(message) }
  }
}

private struct StatusLine: View {
  let session: ProofreadingSession
  let message: String?

  var body: some View {
    HStack {
      if session.activity == .failed(.planLimitReached) {
        Text("Plan limit reached").foregroundStyle(.red)
      } else {
        Text("\(tokens(session.usage.total)) tokens")
          .help(
            "Fix \(tokens(session.usage.fix)) · Explain \(tokens(session.usage.explain)) · "
              + "Intent \(tokens(session.usage.intent))")
      }
      Spacer()
      if let message { Text(message).lineLimit(1).help(message) }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
  }

  private func tokens(_ count: Int) -> String {
    count < 1000 ? "\(count)" : String(format: "%.1fk", Double(count) / 1000)
  }
}

private struct NothingToCheckView: View {
  let app: AppModel

  var body: some View {
    VStack(spacing: 12) {
      Text("Nothing to check. Select text or put the cursor in a text field.")
        .multilineTextAlignment(.center)
      Button("Check Clipboard") { app.checkClipboard() }
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
