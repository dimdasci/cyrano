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
          Text(reading(for: timeline.date.timeIntervalSince(since)))
        }
        Button("Skip") { session.stopReadingContext() }
          .buttonStyle(.link)
          .help("Stop reading and check without the context")
      case .nothingFound:
        Text(status.message)
      case .timedOut, .failed:
        warning(status.message)
          .help(status.detail ?? "")
          .accessibilityHint(status.detail ?? "")
        if status.canTryAgain {
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
  private func reading(for elapsed: TimeInterval) -> String {
    let seconds = Int(elapsed)
    return seconds < 3 ? status.message : "\(status.message) \(seconds) s"
  }
}
