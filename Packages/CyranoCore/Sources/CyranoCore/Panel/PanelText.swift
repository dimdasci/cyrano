// What the panel says in words: card summaries, error lines, and what VoiceOver reads and
// announces, in the interface language. See docs/specs/05-ui.md §2.3a, §2.4, §2.8, §7.

import Foundation

/// A change as the user sees it: an error or a style suggestion, once its reason says which. Until
/// the reason arrives, and when Explain failed or skipped the change, its category is unknown.
public enum ChangeKind: Sendable {
  case error
  case style
  case unknown

  init(_ reason: Explanation?) {
    self =
      switch reason?.category {
      case nil: .unknown
      case .style: .style
      case .grammar, .spelling, .punctuation, .wordChoice: .error
      }
  }
}

extension Version {
  /// The summary line of the card: "5 fixes · 1 style suggestion", "Explaining…".
  public var summary: String {
    switch edit {
    case .translation(let language):
      return localized("Translated to \(InterfaceLanguage.current.name(of: language))")
    case .corrections(let diff, _) where diff.changes.isEmpty:
      return localized("No changes needed")
    case .corrections(_, .pending):
      return localized("Explaining…")
    case .corrections(let diff, .unavailable):
      return localized("\(diff.changes.count) changes")
    case .corrections(let diff, .ready):
      let kinds = diff.changes.map(kind(of:))
      let fixes = kinds.count(.error)
      let style = kinds.count(.style)
      let unknown = kinds.count(.unknown)
      let known = [
        fixes > 0 ? localized("\(fixes) fixes") : nil,
        style > 0 ? localized("\(style) style suggestions") : nil,
      ].compactMap(\.self)
      // A change Explain skipped isn't counted as a fix.
      let other =
        unknown == 0
        ? nil
        : known.isEmpty ? localized("\(unknown) changes") : localized("\(unknown) other changes")
      return (known + [other].compactMap(\.self)).joined(separator: " · ")
    }
  }

  /// The reason for a change, once Explain has given one.
  public func reason(for change: Change) -> Explanation? {
    guard case .corrections(_, .ready(let reasons)) = edit else { return nil }
    return reasons[change.id]
  }

  /// How the card marks a change (05 §2.4).
  public func kind(of change: Change) -> ChangeKind {
    ChangeKind(reason(for: change))
  }

  /// What VoiceOver says when the card appears, before its reasons arrive: "Version 2, 1 change".
  public var announcement: String {
    switch edit {
    case .translation(let language):
      localized("Version \(number), translated to \(InterfaceLanguage.current.name(of: language))")
    case .corrections(let diff, _) where diff.changes.isEmpty:
      localized("Version \(number), no changes needed")
    case .corrections(let diff, _):
      localized("Version \(number), \(diff.changes.count) changes")
    }
  }
}

extension [ChangeKind] {
  fileprivate func count(_ kind: ChangeKind) -> Int { count { $0 == kind } }
}

extension Change {
  /// A row of the list of changes as VoiceOver reads it: the change, its kind ("change" until the
  /// reason comes), then the reason. "has, replaced with have, error. Tense."
  public func spoken(reason: Explanation?) -> String {
    let kind =
      switch ChangeKind(reason) {
      case .error: localized("error")
      case .style: localized("style suggestion")
      case .unknown: localized("change")
      }
    let edit =
      switch (words[0], words[1]) {
      case ("", let new): localized("\(new), added")
      case (let old, ""): localized("\(old), removed")
      case (let old, let new): localized("\(old), replaced with \(new)")
      }
    let label = "\(edit), \(kind)"
    return reason.map { "\(label). \($0.reason)" } ?? label
  }
}

extension EngineError {
  /// The error card in the feed (05 §2.8).
  public var message: String {
    switch self {
    case .notSignedIn: localized("Sign in to ChatGPT to check text.")
    case .planLimitReached: localized("Your ChatGPT plan limit for this app is reached.")
    case .planUsageUnavailable:
      localized("ChatGPT plan usage isn't available for this app right now.")
    case .network: localized("Couldn't reach OpenAI.")
    case .timedOut: localized("OpenAI stopped answering. Try again in a moment.")
    case .signInNotSaved:
      localized(
        """
        Cyrano couldn't save your ChatGPT sign-in to the Keychain. Choose Try Again and allow \
        access when macOS asks; if Cyrano quits first, you'll need to sign in again.
        """)
    case .failed(let detail): localized("The check failed: \(detail)")
    }
  }
}

extension ContextStatus {
  /// The line by the Context title (05 §2.3a).
  public var message: String {
    switch self {
    case .reading: localized("Reading the conversation…")
    case .nothingFound: localized("No conversation found in this window")
    case .timedOut: localized("Reading took too long")
    case .failed(.notSignedIn): localized("Couldn't read: not signed in to ChatGPT")
    case .failed(.planLimitReached): localized("Couldn't read: plan limit reached")
    case .failed(.planUsageUnavailable): localized("Couldn't read: plan usage unavailable")
    case .failed(.network): localized("Couldn't reach OpenAI")
    case .failed(.timedOut): localized("Couldn't read: OpenAI stopped answering")
    case .failed(.signInNotSaved):
      localized("Couldn't read: sign-in not saved to the Keychain")
    case .failed(.failed): localized("Couldn't read the conversation")
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
