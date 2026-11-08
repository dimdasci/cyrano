// The chat feed: version cards, requests, answers, progress and errors. See docs/specs/05-ui.md §2.4.

import CyranoCore
import SwiftUI

struct FeedView: View {
  let model: PanelModel
  @Bindable var session: ProofreadingSession
  /// How much taller the feed must be to show everything in it; the panel grows by it (05 §2.1).
  @Binding var shortfall: CGFloat
  @State private var contentHeight = Self.minHeight
  @State private var visibleHeight = Self.minHeight

  private static let minHeight: CGFloat = 80

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if session.feed.isEmpty {
            TextToCheck(model: model, session: session)
          }
          ForEach(session.feed) { item in
            row(item)
          }
          ActivityRow(model: model, session: session)
          Color.clear.frame(height: 1).id("bottom")
        }
        .padding(12)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) {
          contentHeight = $0
          shortfall = max(contentHeight, Self.minHeight) - visibleHeight
        }
      }
      .frame(minHeight: Self.minHeight, idealHeight: contentHeight, maxHeight: .infinity)
      .onGeometryChange(for: CGFloat.self, of: \.size.height) {
        visibleHeight = $0
        shortfall = max(contentHeight, Self.minHeight) - visibleHeight
      }
      .onChange(of: session.feed) { proxy.scrollTo("bottom") }
      .onChange(of: session.activity) { proxy.scrollTo("bottom") }
    }
    .accessibilityLabel("Proofreading results")
  }

  @ViewBuilder private func row(_ item: FeedItem) -> some View {
    switch item {
    case .version(let version):
      VersionCard(
        version: version, isLatest: version.number == session.versions.last?.number,
        actions: actions)
    case .request(_, let text):
      Bubble(text: text, fromUser: true)
    case .answer(_, let text):
      Bubble(text: text, fromUser: false)
    }
  }

  private var actions: VersionCard.Actions {
    VersionCard.Actions(
      copy: { model.copy($0) },
      reject: { session.reject($0) },
      selectionItem: { model.selectionItem(for: $0) },
      changeItems: { model.changeItems(for: $0) })
  }
}

/// The text before the first check: captured text to fix up, or an empty field to type or paste
/// into when nothing was captured (05 §2.4).
private struct TextToCheck: View {
  let model: PanelModel
  @Bindable var session: ProofreadingSession

  var body: some View {
    Card(title: "Text to check") {
      EditableText(text: $session.original, isEditable: !isChecking) { selection in
        TermDictionary.term(fromSelection: selection).map(model.selectionItem)
      }
      .overlay(alignment: .topLeading) {
        if session.original.isEmpty {
          Text(EditableText.placeholder)
            .font(.system(size: 14))
            .foregroundStyle(.tertiary)
            .allowsHitTesting(false)
            // The field itself reads it as its placeholder.
            .accessibilityHidden(true)
        }
      }
    }
  }

  /// Context may still be read while the user fixes the text; a running check freezes it.
  private var isChecking: Bool {
    if case .checking = session.activity { true } else { false }
  }
}

/// The author's message on the right on an accent tint, an answer on the left. Text keeps the
/// label color: white on the accent color is below 4.5:1 (05 §7).
struct Bubble: View {
  let text: String
  let fromUser: Bool

  var body: some View {
    Text(text)
      .textSelection(.enabled)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        fromUser ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: 10)
      )
      .accessibilityElement(children: .ignore)
      .accessibilityAddTraits(.isStaticText)
      .accessibilityLabel((fromUser ? "You: " : "Answer: ") + text)
      .frame(maxWidth: 400, alignment: fromUser ? .trailing : .leading)
      .frame(maxWidth: .infinity, alignment: fromUser ? .trailing : .leading)
  }
}

/// What is happening now: a streaming version or answer, or an error with a way out. With Reduce
/// Motion nothing streams: the text shows whole once it's ready (05 §7).
private struct ActivityRow: View {
  let model: PanelModel
  let session: ProofreadingSession
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    switch session.activity {
    case .idle:
      EmptyView()
    case .checking(let partial):
      let partial = reduceMotion ? "" : partial
      Card(title: "Version \(session.versions.count + 1)") {
        ProgressView().progressViewStyle(.linear)
          .accessibilityLabel("Checking")
        Text(partial.isEmpty ? session.latestText : partial)
          .foregroundStyle(partial.isEmpty ? .secondary : .primary)
      }
    case .replying(let partial):
      let partial = reduceMotion ? "" : partial
      Bubble(text: partial.isEmpty ? "…" : partial, fromUser: false)
    case .failed(let error):
      ErrorRow(error: error, session: session) {
        model.signInAndRetry()
      } copyOriginal: {
        model.copy(session.original)
      }
    }
  }
}

private struct ErrorRow: View {
  let error: EngineError
  let session: ProofreadingSession
  let signIn: () -> Void
  let copyOriginal: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(error.message)
      HStack {
        if error == .notSignedIn {
          Button("Continue with ChatGPT", action: signIn).buttonStyle(.borderedProminent)
        } else {
          if error != .planLimitReached {
            Button("Try Again") { Task { await session.tryAgain() } }
          }
          Button("Copy Original", action: copyOriginal)
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

struct Card<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
      content
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
  }
}
