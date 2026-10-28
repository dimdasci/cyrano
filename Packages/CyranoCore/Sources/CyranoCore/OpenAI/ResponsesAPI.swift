// Wire format of POST /v1/responses with stream: true. See docs/specs/02-tech-decisions.md M2, M6.

import Foundation

enum ResponsesRequest {
  static func body(model: Model, call: ModelCall) -> JSONValue {
    var body: [String: JSONValue] = [
      "model": .string(model.rawValue),
      "instructions": .string(call.instructions),
      "input": .array(call.input.map(message)),
      "store": false,
      "stream": true,
      "reasoning": ["effort": "low"],
    ]
    if let schema = call.schema {
      body["text"] = [
        "format": ["type": "json_schema", "name": "result", "schema": schema, "strict": true]
      ]
    }
    return .object(body)
  }

  private static func message(_ message: ChatMessage) -> JSONValue {
    let type: JSONValue = message.role == .assistant ? "output_text" : "input_text"
    let images: [JSONValue] = message.images.map { image in
      [
        "type": "input_image",
        "image_url": .string("data:image/png;base64,\(image.base64EncodedString())"),
      ]
    }
    return [
      "role": .string(message.role.rawValue),
      "content": .array([["type": type, "text": .string(message.text)]] + images),
    ]
  }
}

/// One server-sent event of the stream that matters to us.
enum StreamEvent: Equatable {
  case delta(String)
  case completed(tokens: Int)
  case failed(EngineError)

  /// Parses one `data:` line; other lines and unknown events give nil.
  init?(line: String) {
    guard line.hasPrefix("data:") else { return nil }
    let payload = Data(String(line.dropFirst(5)).trimmed.utf8)
    guard let raw = try? JSONDecoder().decode(RawEvent.self, from: payload) else { return nil }
    switch raw.type {
    case "response.output_text.delta": self = .delta(raw.delta ?? "")
    case "response.completed": self = .completed(tokens: raw.response?.usage?.totalTokens ?? 0)
    case "response.failed", "error":
      self = .failed((raw.response?.error ?? raw.error)?.engineError ?? .failed(raw.type))
    default: return nil
    }
  }
}

private struct RawEvent: Decodable {
  struct Usage: Decodable {
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
      case totalTokens = "total_tokens"
    }
  }

  struct Response: Decodable {
    let usage: Usage?
    let error: APIError?
  }

  let type: String
  let delta: String?
  let response: Response?
  let error: APIError?
}

struct APIError: Decodable {
  let code: String?
  let message: String?

  var engineError: EngineError {
    switch code {
    case "subscription_sharing_usage_limit_exceeded": .planLimitReached
    case "subscription_sharing_usage_unavailable": .planUsageUnavailable
    default: .failed(message ?? code ?? "Unknown error")
    }
  }

  /// Maps a non-200 response body to an error.
  static func engineError(status: Int, body: String) -> EngineError {
    if status == 401 { return .notSignedIn }
    struct Envelope: Decodable { let error: APIError }
    let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(body.utf8))
    return envelope?.error.engineError ?? .failed("HTTP \(status): \(body.prefix(300))")
  }
}
