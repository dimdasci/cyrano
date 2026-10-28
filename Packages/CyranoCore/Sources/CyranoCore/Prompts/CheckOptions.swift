// What the user picks in the panel header. See docs/specs/03-mvp-scope.md and 05-ui.md §2.3.

import Foundation

public enum TextType: String, CaseIterable, Codable, Sendable {
  case message
  case email
  case docs

  public var title: String {
    switch self {
    case .message: "Message"
    case .email: "Email"
    case .docs: "Docs"
    }
  }
}

public enum Tone: String, CaseIterable, Codable, Sendable {
  case neutral
  case casual
  case friendly
  case professional
  case concise

  public var title: String { rawValue.capitalized }
}

public enum Level: String, CaseIterable, Codable, Sendable {
  case errorsOnly
  case fluency
  case rewrite

  public var title: String {
    switch self {
    case .errorsOnly: "Errors Only"
    case .fluency: "Fluency"
    case .rewrite: "Rewrite"
    }
  }
}

public enum OutputLanguage: String, CaseIterable, Codable, Sendable {
  case sameAsText
  case englishUS
  case englishUK
  case russian
  case german
  case spanish

  public var title: String {
    switch self {
    case .sameAsText: "Same as Text"
    case .englishUS: "English (US)"
    case .englishUK: "English (UK)"
    case .russian: "Russian"
    case .german: "German"
    case .spanish: "Spanish"
    }
  }

  /// How the language is named inside prompts.
  var promptName: String {
    self == .sameAsText ? "the same language as the TEXT" : title
  }
}

public struct CheckOptions: Hashable, Codable, Sendable {
  public var textType: TextType
  public var tone: Tone
  public var level: Level
  public var language: OutputLanguage
  public var customInstructions: String

  public init(
    textType: TextType = .message, tone: Tone = .neutral, level: Level = .fluency,
    language: OutputLanguage = .sameAsText, customInstructions: String = ""
  ) {
    self.textType = textType
    self.tone = tone
    self.level = level
    self.language = language
    self.customInstructions = customInstructions
  }
}
