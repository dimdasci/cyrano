// Context type, tone, level and language per app, remembered from the panel header and listed
// in Settings → Style. See docs/specs/02 S2 and 05-ui.md §2.3, §5.

public import Foundation
public import Observation

@MainActor @Observable
public final class AppDefaults {
  /// One app and its options; a nil bundle id is text typed or pasted into the panel.
  public struct Entry: Hashable, Sendable, Identifiable {
    public let bundleID: String?
    public let options: CheckOptions

    public var id: String { AppDefaults.key(bundleID) }
  }

  public private(set) var entries: [Entry]
  @ObservationIgnored private let defaults: UserDefaults

  /// One key per app, `options.<bundle id>`, holding JSON as since 0.1.
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    entries = Self.read(defaults)
  }

  public func options(for bundleID: String?) -> CheckOptions {
    entries.first { $0.bundleID == bundleID }?.options ?? CheckOptions()
  }

  /// Custom instructions belong to Style, not to the app.
  public func remember(_ options: CheckOptions, for bundleID: String?) {
    var stored = options
    stored.customInstructions = ""
    defaults.set(try? JSONEncoder().encode(stored), forKey: Self.key(bundleID))
    entries = Self.read(defaults)
  }

  /// The app goes back to Message · Neutral · Fluency · Same as Text.
  public func reset(_ bundleID: String?) {
    defaults.removeObject(forKey: Self.key(bundleID))
    entries = Self.read(defaults)
  }

  nonisolated private static let prefix = "options."
  nonisolated private static let manual = "manual"

  nonisolated private static func key(_ bundleID: String?) -> String {
    prefix + (bundleID ?? manual)
  }

  private static func read(_ defaults: UserDefaults) -> [Entry] {
    defaults.dictionaryRepresentation().compactMap { key, value in
      guard key.hasPrefix(prefix), let data = value as? Data,
        let options = try? JSONDecoder().decode(CheckOptions.self, from: data)
      else { return nil }
      let app = String(key.dropFirst(prefix.count))
      return Entry(bundleID: app == manual ? nil : app, options: options)
    }
    .sorted { $0.id < $1.id }
  }
}
