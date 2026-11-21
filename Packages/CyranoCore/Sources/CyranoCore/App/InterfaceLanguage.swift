// The language the interface speaks and the explanations are written in. See docs/specs/05-ui.md
// §6 and 02-tech-decisions.md M7.

import Foundation

/// The first of the user's languages that Cyrano has, or English for any other. The app's own
/// texts pick their language the same way, from the same three: English, Spanish and Russian.
public struct InterfaceLanguage: Hashable, Sendable {
  /// "en", "es" or "ru", as the String Catalog names it.
  public let code: String

  /// The language of the running app; a test sets it for the code it calls.
  @TaskLocal public static var current = InterfaceLanguage(
    preferences: Locale.preferredLanguages)

  /// The language for a user whose languages are `preferences`, the first one first.
  public init(preferences: [String]) {
    let languages = Bundle.module.localizations
    let picked = Bundle.preferredLocalizations(from: languages, forPreferences: preferences)
    code = picked.first.flatMap { languages.contains($0) ? $0 : nil } ?? "en"
  }

  /// Every language Cyrano speaks, English first: en, es, ru.
  public static var all: [InterfaceLanguage] {
    let others: [String] = Bundle.module.localizations.filter { $0 != "en" && $0 != "Base" }
    return (["en"] + others.sorted()).map { InterfaceLanguage(preferences: [$0]) }
  }

  /// The language's name in itself, as a menu of languages shows it: "Español".
  public var ownName: String {
    let locale = Locale(identifier: code)
    return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code
  }

  /// The language's name in English, for the prompts: "Russian".
  var englishName: String {
    Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
  }

  /// Another language's name in this one, as it reads inside a sentence: "alemán".
  func name(of language: String) -> String {
    Locale(identifier: code).localizedString(forLanguageCode: language) ?? language
  }

  /// A text from Core's String Catalog in this language, with its plural and format rules.
  func text(_ value: String.LocalizationValue) -> String {
    String(localized: value, bundle: bundle, locale: Locale(identifier: code))
  }

  private var bundle: Bundle {
    Bundle.module.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .module
  }
}

/// A text from Core's String Catalog in the interface language.
func localized(_ value: String.LocalizationValue) -> String {
  InterfaceLanguage.current.text(value)
}
