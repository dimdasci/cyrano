// Telling a translation from a correction: the dominant language of the text changed.

import Foundation
import NaturalLanguage

enum Language {
  /// The code of the language of `new` ("de") when it differs from the language of `old`.
  /// Short or mixed texts without a confident guess count as the same language.
  static func translation(from old: String, to new: String) -> String? {
    guard let from = dominant(old), let into = dominant(new), from != into else { return nil }
    return into.rawValue
  }

  private static func dominant(_ text: String) -> NLLanguage? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
      confidence > 0.8
    else { return nil }
    return language
  }
}
