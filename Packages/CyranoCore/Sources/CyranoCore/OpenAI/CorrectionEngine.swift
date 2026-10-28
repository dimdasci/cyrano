// The model behind the panel. See docs/specs/02-tech-decisions.md (T8, M2).

public import Foundation

public struct ChatMessage: Hashable, Sendable {
  public enum Role: String, Sendable {
    case user
    case assistant
  }

  public let role: Role
  public let text: String
  /// PNG images sent after the text (M10).
  public let images: [Data]

  public init(_ role: Role, _ text: String, images: [Data] = []) {
    self.role = role
    self.text = text
    self.images = images
  }
}

/// One model call: instructions, the whole dialog as input, and an optional JSON output schema.
public struct ModelCall: Hashable, Sendable {
  public let instructions: String
  public let input: [ChatMessage]
  public let schema: JSONValue?

  public init(instructions: String, input: [ChatMessage], schema: JSONValue? = nil) {
    self.instructions = instructions
    self.input = input
    self.schema = schema
  }
}

public enum ResponseUpdate: Hashable, Sendable {
  case delta(String)
  case completed(text: String, tokens: Int)
}

public protocol CorrectionEngine: Sendable {
  /// Streams the output text; finishes with `.completed` or throws `EngineError`.
  func respond(_ call: ModelCall) -> AsyncThrowingStream<ResponseUpdate, any Error>
}

/// Failures the panel tells apart. See docs/specs/05-ui.md §2.8.
public enum EngineError: Error, Hashable, Sendable {
  case notSignedIn
  case planLimitReached
  case planUsageUnavailable
  case network
  case failed(String)
}

public enum Model: String, CaseIterable, Codable, Sendable {
  case sol = "gpt-6.1-sol"
  case luna = "gpt-6-luna"

  public var title: String {
    switch self {
    case .sol: "\(rawValue) — Best quality"
    case .luna: "\(rawValue) — Faster"
    }
  }
}
