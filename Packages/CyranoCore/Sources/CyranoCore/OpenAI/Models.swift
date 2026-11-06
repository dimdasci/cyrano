// The models Cyrano offers and which one answers each kind of call. See docs/specs/02 M1.

public import Foundation

/// Models checked on our evals; a new one comes with a release, not from the server.
public enum Model: String, CaseIterable, Codable, Sendable {
  case sol = "gpt-6.1-sol"
  case terra = "gpt-6.1-terra"
  case luna = "gpt-6-luna"
}

/// The model for each operation the user can see, chosen in Settings → General.
public struct ModelChoice: Hashable, Sendable {
  /// Reads who the user is replying to from a screenshot (C6).
  public var context: Model
  /// Checks, rechecks, dialog answers and new versions, and classifies dialog messages.
  public var proofreading: Model
  /// Reasons for the changes of a version.
  public var explanations: Model

  public init(context: Model = .terra, proofreading: Model = .sol, explanations: Model = .sol) {
    self.context = context
    self.proofreading = proofreading
    self.explanations = explanations
  }
}

/// UserDefaults keys; "model" is the one model of releases before 0.5.
extension ModelChoice {
  private static var keys: [(WritableKeyPath<Self, Model>, String)] {
    [
      (\.context, "model.context"), (\.proofreading, "model"),
      (\.explanations, "model.explanations"),
    ]
  }

  /// A stored model that is no longer offered falls back to the default for its operation.
  public init(from defaults: UserDefaults) {
    self.init()
    for (operation, key) in Self.keys {
      if let model = defaults.string(forKey: key).flatMap(Model.init) {
        self[keyPath: operation] = model
      }
    }
  }

  public func save(to defaults: UserDefaults) {
    for (operation, key) in Self.keys {
      defaults.set(self[keyPath: operation].rawValue, forKey: key)
    }
  }
}
