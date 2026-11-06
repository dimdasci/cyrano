// A Context eval case: a window with the draft in its input field, as a real screenshot or a
// synthetic window drawn from a template. See evals/context/README.md.

import CoreGraphics
import Foundation

struct ContextCase: Decodable {
  let id: String
  let window: Window
  /// The draft.
  let text: String
  /// The context we want, written by hand; for reading, not checked.
  let target: String?
  let expect: Checks

  private enum CodingKeys: String, CodingKey {
    case id, image, page, text, target, expect
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(String.self, forKey: .id)
    text = try values.decode(String.self, forKey: .text)
    target = try values.decodeIfPresent(String.self, forKey: .target)
    expect = try values.decode(Checks.self, forKey: .expect)
    if let page = try values.decodeIfPresent(Page.self, forKey: .page) {
      window = .page(page)
    } else {
      window = .screenshot(try values.decode(String.self, forKey: .image))
    }
  }
}

/// Paths are relative to the cases file.
enum Window {
  case screenshot(String)
  case page(Page)
}

/// A template with a data file for its render(data, draft).
struct Page: Decodable {
  let template: String
  let data: String
  let size: CGSize

  private enum CodingKeys: String, CodingKey {
    case template, data, width, height
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    template = try values.decode(String.self, forKey: .template)
    data = try values.decode(String.self, forKey: .data)
    size = CGSize(
      width: try values.decodeIfPresent(Double.self, forKey: .width) ?? 1440,
      height: try values.decodeIfPresent(Double.self, forKey: .height) ?? 900)
  }
}

/// Clear errors only: what must and must not be in the context, or that there is none.
struct Checks: Decodable {
  let mustContain: [String]
  let mustNotContain: [String]
  let empty: Bool

  private enum CodingKeys: String, CodingKey {
    case mustContain, mustNotContain, empty
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    mustContain = try values.decodeIfPresent([String].self, forKey: .mustContain) ?? []
    mustNotContain = try values.decodeIfPresent([String].self, forKey: .mustNotContain) ?? []
    empty = try values.decodeIfPresent(Bool.self, forKey: .empty) ?? false
  }

  func failures(in output: String) -> [String] {
    if empty {
      return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? [] : ["expected no context"]
    }
    let text = Self.normalized(output)
    return mustContain.filter { !text.contains(Self.normalized($0)) }.map { "missing \"\($0)\"" }
      + mustNotContain.filter { text.contains(Self.normalized($0)) }.map { "has \"\($0)\"" }
  }

  /// Case and typographic quotes don't matter.
  private static func normalized(_ text: String) -> String {
    text.lowercased()
      .replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'")
      .replacingOccurrences(of: "“", with: "\"").replacingOccurrences(of: "”", with: "\"")
  }
}
