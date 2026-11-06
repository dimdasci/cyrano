public import Foundation

/// A JSON value, for the parts of a request whose shape is data (output schemas).
public indirect enum JSONValue: Hashable, Sendable {
  case string(String)
  case bool(Bool)
  case int(Int)
  case array([JSONValue])
  /// Keys keep their order: the model fills a schema's fields in the order they are listed.
  case object([Member])

  public struct Member: Hashable, Sendable {
    public let key: String
    public let value: JSONValue

    public init(_ key: String, _ value: JSONValue) {
      self.key = key
      self.value = value
    }
  }

  /// JSON text with object keys in their order; JSONEncoder would not keep it.
  public var json: Data {
    switch self {
    case .string(let value): Self.quoted(value)
    case .bool(let value): Data((value ? "true" : "false").utf8)
    case .int(let value): Data(String(value).utf8)
    case .array(let values): Self.joined(values.map(\.json), "[", "]")
    case .object(let members):
      Self.joined(members.map { Self.quoted($0.key) + Data(":".utf8) + $0.value.json }, "{", "}")
    }
  }

  private static func quoted(_ string: String) -> Data {
    // Encoding a string escapes it and cannot fail.
    (try? JSONEncoder().encode(string)) ?? Data()
  }

  private static func joined(_ parts: [Data], _ open: String, _ close: String) -> Data {
    Data(open.utf8) + parts.joined(separator: Data(",".utf8)) + Data(close.utf8)
  }
}

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByBooleanLiteral,
  ExpressibleByIntegerLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
  public init(stringLiteral value: String) { self = .string(value) }
  public init(booleanLiteral value: Bool) { self = .bool(value) }
  public init(integerLiteral value: Int) { self = .int(value) }
  public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
  public init(dictionaryLiteral elements: (String, JSONValue)...) {
    self = .object(elements.map(Member.init))
  }
}
