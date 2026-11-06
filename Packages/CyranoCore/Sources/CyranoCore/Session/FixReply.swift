// What Fix replies: JSON by a schema, the kind first, then the text. Parsed here, at the boundary.
// See docs/specs/04-prompts.md §4.3.

import Foundation

/// The kinds of reply a Fix call allows. Its schema lists exactly these.
protocol ReplyKind: RawRepresentable<String>, CaseIterable, Decodable, Hashable, Sendable {}

/// The first check and a recheck write a version and nothing else: a text that asks a question is
/// still a text to correct.
enum CheckKind: String, ReplyKind {
  case version
}

/// A dialog message gets a new version, or an answer: an explanation or a question back.
enum DialogKind: String, ReplyKind {
  case version
  case answer
}

struct FixReply<Kind: ReplyKind>: Decodable, Hashable, Sendable {
  let kind: Kind
  let text: String

  init(kind: Kind, text: String) {
    self.kind = kind
    self.text = text
  }

  /// Nil when the output isn't the fields asked for or names a kind this call doesn't allow.
  init?(output: String) {
    guard let reply = try? JSONDecoder().decode(Self.self, from: Data(output.utf8)) else {
      return nil
    }
    self = reply
  }

  static var schema: JSONValue {
    [
      "type": "object", "additionalProperties": false, "required": ["kind", "text"],
      "properties": [
        "kind": ["type": "string", "enum": .array(Kind.allCases.map { .string($0.rawValue) })],
        "text": ["type": "string"],
      ],
    ]
  }
}

/// A reply as it streams: its kind once that string is complete, and the text decoded so far.
/// Reads any JSON object of string members, with whitespace and escapes split across deltas.
struct PartialReply: Hashable, Sendable {
  private(set) var kind: String?
  private(set) var text = ""

  private enum Place: Hashable, Sendable {
    case between
    case key
    case beforeValue
    case value
  }

  private var place = Place.between
  private var key = ""
  private var string = JSONString()

  mutating func append(_ delta: String) {
    for scalar in delta.unicodeScalars { read(scalar) }
    if place == .value, key == "text" { text = string.value }
  }

  private mutating func read(_ scalar: Unicode.Scalar) {
    switch place {
    case .between where scalar == "\"":
      string = JSONString()
      place = .key
    case .beforeValue where scalar == "\"":
      string = JSONString()
      place = .value
    case .beforeValue where scalar == ",":
      place = .between
    case .key where string.read(scalar):
      key = string.value
      place = .beforeValue
    case .value where string.read(scalar):
      if key == "kind" { kind = string.value }
      if key == "text" { text = string.value }
      place = .between
    case .between, .beforeValue, .key, .value:
      break
    }
  }
}

/// The inside of a JSON string, decoded one scalar at a time.
private struct JSONString: Hashable, Sendable {
  private(set) var value = ""
  /// After a backslash: nil for a plain character, the hex digits read so far for `\u`.
  private var escape: String?
  private var inEscape = false
  private var highSurrogate: UInt32?

  /// Reads one scalar; true at the closing quote.
  mutating func read(_ scalar: Unicode.Scalar) -> Bool {
    if let hex = escape {
      readHex(hex + String(scalar))
    } else if inEscape {
      inEscape = false
      readEscaped(scalar)
    } else if scalar == "\\" {
      inEscape = true
    } else if scalar == "\"" {
      return true
    } else {
      value.unicodeScalars.append(scalar)
    }
    return false
  }

  private mutating func readEscaped(_ scalar: Unicode.Scalar) {
    let decoded: [Unicode.Scalar: Unicode.Scalar] = [
      "n": "\n", "t": "\t", "r": "\r", "b": "\u{8}", "f": "\u{c}",
    ]
    if scalar == "u" {
      escape = ""
    } else {
      value.unicodeScalars.append(decoded[scalar] ?? scalar)
    }
  }

  private mutating func readHex(_ hex: String) {
    guard hex.count == 4 else {
      escape = hex
      return
    }
    escape = nil
    guard let code = UInt32(hex, radix: 16) else { return }
    if (0xD800..<0xDC00).contains(code) {
      highSurrogate = code
      return
    }
    var scalar = code
    if let high = highSurrogate, (0xDC00..<0xE000).contains(code) {
      scalar = 0x10000 + ((high - 0xD800) << 10) + (code - 0xDC00)
    }
    highSurrogate = nil
    if let decoded = Unicode.Scalar(scalar) { value.unicodeScalars.append(decoded) }
  }
}
