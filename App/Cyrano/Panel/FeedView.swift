// The chat feed: version cards, requests, answers, progress and errors. See docs/specs/05-ui.md §2.4.

import CyranoCore
import SwiftUI

struct FeedView: View {
  let model: PanelModel
  let session: ProofreadingSession

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          if session.feed.isEmpty {
            Card(title: "Text to check") {
              Text(session.original).font(.system(size: 14)).textSelection(.enabled)
            }
          }
          ForEach(session.feed) { item in
            row(item)
          }
          ActivityRow(model: model, session: session)
          Color.clear.frame(height: 1).id("bottom")
        }
        .padding(12)
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
    case .request(_, let text, _):
      Bubble(text: text, fromUser: true)
    case .answer(_, let text):
      Bubble(text: text, fromUser: false)
    }
  }

  private var actions: VersionCard.Actions {
    VersionCard.Actions(
      copy: { model.copy($0) },
      reject: { session.reject($0) })
  }
}

struct Bubble: View {
  let text: String
  let fromUser: Bool

  var body: some View {
    Text(text)
      .textSelection(.enabled)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .foregroundStyle(fromUser ? Color.white : Color.primary)
      .background(
        fromUser ? Color.accentColor : Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: 10)
      )
      .frame(maxWidth: 400, alignment: fromUser ? .trailing : .leading)
      .frame(maxWidth: .infinity, alignment: fromUser ? .trailing : .leading)
  }
}

/// What is happening now: streaming text, a pending request, or an error with a way out.
private struct ActivityRow: View {
  let model: PanelModel
  let session: ProofreadingSession

  var body: some View {
    switch session.activity {
    case .idle:
      EmptyView()
    case .checking(let partial):
      Card(title: "Version \(session.versions.count + 1)") {
        ProgressView().progressViewStyle(.linear)
        Text(partial.isEmpty ? session.latestText : partial)
          .foregroundStyle(partial.isEmpty ? .secondary : .primary)
      }
    case .replying(let request, let partial):
      Bubble(text: request, fromUser: true)
      Bubble(text: partial.isEmpty ? "…" : partial, fromUser: false)
    case .failed(let error):
      ErrorRow(error: error, session: session) {
        model.signInAndRetry(session)
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
      Text(message)
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

  private var message: String {
    switch error {
    case .notSignedIn: "Sign in to ChatGPT to check text."
    case .planLimitReached: "Your ChatGPT plan limit for this app is reached."
    case .planUsageUnavailable: "ChatGPT plan usage isn't available for this app right now."
    case .network: "Couldn't reach OpenAI."
    case .failed(let detail): "The check failed: \(detail)"
    }
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
