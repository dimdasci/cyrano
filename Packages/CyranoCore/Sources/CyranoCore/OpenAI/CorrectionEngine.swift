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

/// One model call: the model, instructions, the whole dialog as input, and an optional JSON
/// output schema.
public struct ModelCall: Hashable, Sendable {
  public let model: Model
  public let instructions: String
  public let input: [ChatMessage]
  public let schema: JSONValue?

  public init(
    model: Model, instructions: String, input: [ChatMessage], schema: JSONValue? = nil
  ) {
    self.instructions = instructions
    self.input = input
    self.schema = schema
    self.model = model
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
  /// No event arrived for 30 s, after one retry when no text had arrived yet (02 M13).
  case timedOut
  /// A token refresh succeeded, but the Keychain refused the new token. Every request fails with
  /// this and tries to save it again until a save succeeds; meanwhile the token stays in memory,
  /// so it isn't lost (02 A5).
  case signInNotSaved
  case failed(String)
}
