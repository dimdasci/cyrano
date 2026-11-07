// Reading the context of a draft from a screenshot of its window. See docs/specs/02 C6 and
// 04-prompts.md §4.5. The app and cyrano-eval send the same call and read the answer the same way.

public import Foundation

extension ModelCall {
  static func readContext(
    screenshot: Data, draft: String, model: Model, instructions: String
  ) -> ModelCall {
    ModelCall(
      model: model, instructions: instructions,
      input: [ChatMessage(.user, Prompts.contextInput(draft), images: [screenshot])],
      schema: ConversationContext.schema)
  }
}

/// What came of reading the context from the window, shown by the Context title (05 §2.3a).
public enum ContextStatus: Hashable, Sendable {
  case reading(since: Date)
  /// The window shows no conversation the text belongs to.
  case nothingFound
  case timedOut
  case failed(EngineError)
}

/// Who the draft is for, what about and in which language, as the window shows it.
struct ConversationContext: Hashable, Sendable {
  /// Lines for the Context field; empty when nothing on screen relates to the draft.
  let text: String
  /// The language of the conversation, when the panel offers it.
  let language: OutputLanguage?

  /// Nil when the answer is not the fields asked for.
  init?(answer: String) {
    guard let fields = try? JSONDecoder().decode(Fields.self, from: Data(answer.utf8)) else {
      return nil
    }
    let lines: [(String, String?)] = [
      ("With", fields.with), ("Language", fields.language), ("About", fields.about),
      ("Format", fields.format), ("Style", fields.style), ("Formality", fields.formality),
    ]
    text = lines.compactMap { label, value in
      value.map(\.trimmed).flatMap { $0.isEmpty ? nil : "\(label): \($0)" }
    }
    .joined(separator: "\n")
    language = fields.language.flatMap(OutputLanguage.init(conversation:))
  }

  private struct Fields: Decodable {
    let with: String?
    let language: String?
    let about: String?
    let format: String?
    let style: String?
    let formality: String?
  }

  static let schema: JSONValue = {
    let field: JSONValue = ["type": ["string", "null"]]
    // Format before about: whether the draft starts a new topic decides whether there is one.
    let names = ["with", "language", "format", "about", "style", "formality"]
    return [
      "type": "object", "additionalProperties": false,
      "required": .array(names.map(JSONValue.string)),
      "properties": .object(names.map { JSONValue.Member($0, field) }),
    ]
  }()
}
