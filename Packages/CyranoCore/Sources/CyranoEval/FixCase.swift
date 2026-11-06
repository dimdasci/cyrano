// A fix eval case: the text with the panel's header options, Context and dictionary, then the
// dialog messages the user sends. Criteria say in words what should happen; a person reads the
// report and judges them. See docs/specs/04-prompts.md §5.

import CyranoCore
import Foundation

struct FixCase: Decodable {
  enum Source: String, Decodable {
    /// A message the user really wrote.
    case real
    case synthetic
  }

  /// A dialog message after the first check, with what should happen to it.
  struct Turn: Decodable {
    let message: String
    let criteria: [String]
  }

  let id: String
  let source: Source
  let options: CheckOptions
  let context: String
  /// Terms of the "Never change" dictionary.
  let dictionary: [String]
  let text: String
  let criteria: [String]
  let turns: [Turn]
  /// Decisions on what is right in this case, for whoever judges it next.
  let notes: String?
  /// A case the prompts are never tuned on: it only checks that a general rule holds.
  let heldOut: Bool

  private enum CodingKeys: String, CodingKey {
    case id, source, textType, tone, level, language, customInstructions, context, dictionary,
      text, criteria, turns, notes, heldOut
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    source = try values.decode(Source.self, forKey: .source)
    let defaults = CheckOptions()
    options = CheckOptions(
      textType: try values.decodeIfPresent(TextType.self, forKey: .textType) ?? defaults.textType,
      tone: try values.decodeIfPresent(Tone.self, forKey: .tone) ?? defaults.tone,
      level: try values.decodeIfPresent(Level.self, forKey: .level) ?? defaults.level,
      language: try values.decodeIfPresent(OutputLanguage.self, forKey: .language)
        ?? defaults.language,
      customInstructions: try values.decodeIfPresent(String.self, forKey: .customInstructions)
        ?? defaults.customInstructions)
    context = try values.decodeIfPresent(String.self, forKey: .context) ?? ""
    dictionary = try values.decodeIfPresent([String].self, forKey: .dictionary) ?? []
    text = try values.decode(String.self, forKey: .text)
    criteria = try values.decode([String].self, forKey: .criteria)
    turns = try values.decodeIfPresent([Turn].self, forKey: .turns) ?? []
    notes = try values.decodeIfPresent(String.self, forKey: .notes)
    heldOut = try values.decodeIfPresent(Bool.self, forKey: .heldOut) ?? false
  }
}
