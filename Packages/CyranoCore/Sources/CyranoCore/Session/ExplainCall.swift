// Explain: reasons for numbered changes as JSON. See docs/specs/04-prompts.md §4.4.

import Foundation

enum ExplainCall {
  static let schema: JSONValue = [
    "type": "object", "additionalProperties": false, "required": ["items"],
    "properties": [
      "items": [
        "type": "array",
        "items": [
          "type": "object", "additionalProperties": false,
          "required": ["id", "category", "reason"],
          "properties": [
            "id": ["type": "integer"],
            "category": [
              "type": "string",
              "enum": ["grammar", "spelling", "punctuation", "wordChoice", "style"],
            ],
            "reason": ["type": "string"],
          ],
        ],
      ]
    ],
  ]

  static func call(old: String, diff: TextDiff) -> ModelCall {
    ModelCall(
      instructions: Prompts.explain,
      input: [ChatMessage(.user, Prompts.explainInput(old: old, diff: diff))],
      schema: schema)
  }

  /// Reasons by change number; unknown numbers are dropped.
  static func parse(_ output: String, diff: TextDiff) throws -> [Int: Explanation] {
    struct Item: Decodable {
      let id: Int
      let category: Explanation.Category
      let reason: String
    }
    struct Result: Decodable { let items: [Item] }
    let ids = Set(diff.changes.map(\.id))
    let items = try JSONDecoder().decode(Result.self, from: Data(output.utf8)).items
    return Dictionary(
      items.filter { ids.contains($0.id) }
        .map { ($0.id, Explanation(category: $0.category, reason: $0.reason)) },
      uniquingKeysWith: { first, _ in first })
  }
}
