// What the panel says in words: card summaries, error lines, and what VoiceOver reads and
// announces. See docs/specs/05-ui.md §2.3a, §2.4, §2.8, §7.

/// "1 fix", "2 fixes".
public func plural(_ count: Int, _ one: String, _ many: String? = nil) -> String {
  "\(count) \(count == 1 ? one : many ?? one + "s")"
}

extension Version {
  /// The summary line of the card: "5 fixes · 1 style suggestion", "Explaining…".
  public var summary: String {
    switch edit {
    case .translation(let language):
      return "Translated to \(language)"
    case .corrections(let diff, _) where diff.changes.isEmpty:
      return "No changes needed"
    case .corrections(_, .pending):
      return "Explaining…"
    case .corrections(let diff, .unavailable):
      return plural(diff.changes.count, "change")
    case .corrections(let diff, .ready(let reasons)):
      let style = diff.changes.count { reasons[$0.id]?.category == .style }
      let fixes = diff.changes.count - style
      let parts = [
        fixes > 0 ? plural(fixes, "fix", "fixes") : nil,
        style > 0 ? plural(style, "style suggestion") : nil,
      ]
      return parts.compactMap(\.self).joined(separator: " · ")
    }
  }

  /// What VoiceOver says when the card appears, before its reasons arrive: "Version 2, 1 change".
  public var announcement: String {
    let what =
      switch edit {
      case .translation(let language): "translated to \(language)"
      case .corrections(let diff, _) where diff.changes.isEmpty: "no changes needed"
      case .corrections(let diff, _): plural(diff.changes.count, "change")
      }
    return "Version \(number), \(what)"
  }
}

extension Change {
  /// A row of the list of changes as VoiceOver reads it: the change, error or style, then its
  /// reason once it came. "has, replaced with have, error. Tense."
  public func spoken(reason: Explanation?) -> String {
    let kind = reason?.category == .style ? "style suggestion" : "error"
    let edit =
      switch (words[0], words[1]) {
      case ("", let new): "\(new), added"
      case (let old, ""): "\(old), removed"
      case (let old, let new): "\(old), replaced with \(new)"
      }
    let label = "\(edit), \(kind)"
    return reason.map { "\(label). \($0.reason)" } ?? label
  }
}

extension EngineError {
  /// The error card in the feed (05 §2.8).
  public var message: String {
    switch self {
    case .notSignedIn: "Sign in to ChatGPT to check text."
    case .planLimitReached: "Your ChatGPT plan limit for this app is reached."
    case .planUsageUnavailable: "ChatGPT plan usage isn't available for this app right now."
    case .network: "Couldn't reach OpenAI."
    case .timedOut: "OpenAI stopped answering. Try again in a moment."
    case .signInNotSaved:
      "Cyrano couldn't save your ChatGPT sign-in to the Keychain. Choose Try Again and allow "
        + "access when macOS asks; if Cyrano quits first, you'll need to sign in again."
    case .failed(let detail): "The check failed: \(detail)"
    }
  }
}

extension ContextStatus {
  /// The line by the Context title (05 §2.3a).
  public var message: String {
    switch self {
    case .reading: "Reading the conversation…"
    case .nothingFound: "No conversation found in this window"
    case .timedOut: "Reading took too long"
    case .failed(.notSignedIn): "Couldn't read: not signed in to ChatGPT"
    case .failed(.planLimitReached): "Couldn't read: plan limit reached"
    case .failed(.planUsageUnavailable): "Couldn't read: plan usage unavailable"
    case .failed(.network): "Couldn't reach OpenAI"
    case .failed(.timedOut): "Couldn't read: OpenAI stopped answering"
    case .failed(.signInNotSaved): "Couldn't read: sign-in not saved to the Keychain"
    case .failed(.failed): "Couldn't read the conversation"
    }
  }

  /// Try Again reads the screenshot again, unless signing in or the plan is what's missing.
  public var canTryAgain: Bool {
    switch self {
    case .timedOut, .failed(.network), .failed(.timedOut), .failed(.signInNotSaved),
      .failed(.planUsageUnavailable), .failed(.failed):
      true
    case .reading, .nothingFound, .failed(.notSignedIn), .failed(.planLimitReached): false
    }
  }

  /// What went wrong in detail, for the tooltip and VoiceOver.
  public var detail: String? {
    if case .failed(.failed(let detail)) = self { detail } else { nil }
  }
}
