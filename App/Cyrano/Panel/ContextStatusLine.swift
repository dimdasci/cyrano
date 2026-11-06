// The line by the Context title: reading the context from the window, or why it gave nothing.
// The field below holds only the context itself. See docs/specs/05-ui.md §2.3a.

import CyranoCore
import SwiftUI

struct ContextStatusLine: View {
  let session: ProofreadingSession
  let status: ContextStatus

  var body: some View {
    HStack(spacing: 6) {
      switch status {
      case .reading(let since):
        ProgressView().controlSize(.small)
        TimelineView(.periodic(from: since, by: 1)) { timeline in
          Text(Self.reading(for: timeline.date.timeIntervalSince(since)))
        }
        Button("Skip") { session.stopReadingContext() }
          .buttonStyle(.link)
          .help("Stop reading and check without the context")
      case .nothingFound:
        Text("No conversation found in this window")
      case .timedOut:
        warning("Reading took too long")
        tryAgain
      case .failed(let error):
        warning(Self.message(for: error))
          .help(Self.detail(of: error))
        if error != .notSignedIn && error != .planLimitReached {
          tryAgain
        }
      }
    }
    .foregroundStyle(.secondary)
    .lineLimit(1)
  }

  private var tryAgain: some View {
    Button("Try Again") { Task { await session.readContextAgain() } }
      .buttonStyle(.link)
  }

  private func warning(_ text: String) -> some View {
    Label(text, systemImage: "exclamationmark.triangle")
  }

  /// Seconds appear once the wait is longer than usual.
  private static func reading(for elapsed: TimeInterval) -> String {
    let seconds = Int(elapsed)
    return seconds < 3
      ? "Reading the conversation…" : "Reading the conversation… \(seconds) s"
  }

  private static func message(for error: EngineError) -> String {
    switch error {
    case .notSignedIn: "Couldn't read: not signed in to ChatGPT"
    case .planLimitReached: "Couldn't read: plan limit reached"
    case .planUsageUnavailable: "Couldn't read: plan usage unavailable"
    case .network: "Couldn't reach OpenAI"
    case .timedOut: "Couldn't read: OpenAI stopped answering"
    case .signInNotSaved: "Couldn't read: sign-in not saved to the Keychain"
    case .failed: "Couldn't read the conversation"
    }
  }

  private static func detail(of error: EngineError) -> String {
    if case .failed(let detail) = error { detail } else { "" }
  }
}
