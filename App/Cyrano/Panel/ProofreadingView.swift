// Panel layout: header, context, feed, composer, status. See docs/specs/05-ui.md §2.2.

import ApplicationServices
import CyranoCore
import SwiftUI
import UniformTypeIdentifiers

struct ProofreadingView: View {
  let model: PanelModel

  var body: some View {
    @Bindable var session = model.session
    VStack(spacing: 0) {
      PanelHeader(session: session)
        .onChange(of: session.options) { model.optionsChanged() }
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

/// The dialog field and the one action button (05 §2.7). Before the first check there is
/// nothing to talk about yet, so only Check shows.
private struct Composer: View {
  let session: ProofreadingSession
  @State private var draft = ""

  var body: some View {
    HStack(alignment: .bottom, spacing: 8) {
      if session.versions.isEmpty {
        Spacer()
      } else {
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
      }
      // Core decides between Check and Send.
      Button(session.action(for: draft) == .check ? "Check" : "Send", action: perform)
        .disabled(!session.canPerform(message: draft))
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
  }

  private func perform() {
    let message = draft
    draft = ""
    Task { await session.perform(message: message) }
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
        Text("\(tokens(session.tokens)) tokens")
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
