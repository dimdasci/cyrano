// What the panel's chat feed shows. See docs/specs/05-ui.md §2.4.

public struct Explanation: Hashable, Sendable, Decodable {
  public enum Category: String, Hashable, Sendable, Decodable {
    case grammar
    case spelling
    case punctuation
    case wordChoice
    case style
  }

  public let category: Category
  public let reason: String
}

/// One text version from the model and how it differs from the version before it.
public struct Version: Hashable, Sendable {
  public enum Origin: Hashable, Sendable {
    case check
    case recheck
    case request
    case rejection
  }

  public enum Explanations: Hashable, Sendable {
    case pending
    case ready([Int: Explanation])
    case unavailable
  }

  /// How this version relates to the one before it.
  public enum Edit: Hashable, Sendable {
    /// Word-level corrections; their reasons arrive after the version appears.
    case corrections(TextDiff, Explanations)
    /// The previous text in another language, named in English: a word diff would mark every
    /// word as an error.
    case translation(into: String)
  }

  public let number: Int
  public let text: String
  public internal(set) var edit: Edit
  public let origin: Origin

  public var diff: TextDiff? {
    guard case .corrections(let diff, _) = edit else { return nil }
    return diff
  }
}

public enum Intent: Hashable, Sendable {
  case question
  case edit
}

public enum FeedItem: Hashable, Sendable, Identifiable {
  case version(Version)
  case request(id: Int, text: String, intent: Intent)
  case answer(id: Int, text: String)

  public var id: Int {
    switch self {
    case .version(let version): -version.number
    case .request(let id, _, _), .answer(let id, _): id
    }
  }
}
