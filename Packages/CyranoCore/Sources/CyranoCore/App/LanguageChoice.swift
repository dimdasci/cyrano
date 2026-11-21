// The interface language the user picks in Settings → General. See docs/specs/05-ui.md §5, §6.

import Foundation

/// The system's languages or one of Cyrano's. Stored as the app's own `AppleLanguages`: the value
/// System Settings → General → Language & Region → Applications sets for one app, so a choice made
/// in either place shows in both. macOS reads it at launch, so a new choice waits for a relaunch.
public enum LanguageChoice: Hashable, Sendable {
  case system
  case fixed(InterfaceLanguage)

  /// The pop-up: the system first, then each language Cyrano speaks.
  public static var all: [LanguageChoice] { [.system] + InterfaceLanguage.all.map(Self.fixed) }

  /// The choice from the app's own `AppleLanguages`; none means the system's languages. macOS
  /// takes the app's list instead of the system's, so it decides the language on its own.
  public init(appLanguages: [String]?) {
    guard let appLanguages, !appLanguages.isEmpty else {
      self = .system
      return
    }
    self = .fixed(InterfaceLanguage(preferences: appLanguages))
  }

  /// The app's own `AppleLanguages` for this choice; nil removes it.
  public var appLanguages: [String]? {
    switch self {
    case .system: nil
    case .fixed(let language): [language.code]
    }
  }

  /// The language this choice gives on a Mac whose languages are `system`.
  public func language(system: [String]) -> InterfaceLanguage {
    switch self {
    case .system: InterfaceLanguage(preferences: system)
    case .fixed(let language): language
    }
  }

  /// The running app speaks `running` until it is launched again.
  public func needsRelaunch(running: InterfaceLanguage, system: [String]) -> Bool {
    language(system: system) != running
  }
}
