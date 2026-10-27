// Cloud eval runner: runs evals/cases.json on a ChatGPT plan model via Sign in with ChatGPT.
// Build: swiftc -parse-as-library -O OpenAI.swift Shared.swift main.swift -o /tmp/openai-runner
// Usage: openai-runner login | models | run [cases.json]   (MODEL=<id>, EFFORT=low|medium|…)
import Foundation

/// Keeps the dialog history client-side: the plan-usage API has no previous_response_id over HTTP.
final class CloudSession {
  let model: String, instructions: String
  var history: [ChatMessage] = []
  init(model: String, instructions: String) { self.model = model; self.instructions = instructions }

  func respond(to prompt: String) async throws -> String {
    history.append(ChatMessage(role: "user", text: prompt))
    let r = try await OpenAIRunner.respondRetrying(model: model, instructions: instructions, input: history)
    history.append(ChatMessage(role: "assistant", text: r))
    return r
  }
}

let explainSchema: [String: Any] = [
  "type": "object", "additionalProperties": false, "required": ["items"],
  "properties": [
    "items": [
      "type": "array",
      "items": [
        "type": "object", "additionalProperties": false, "required": ["id", "category", "reason"],
        "properties": [
          "id": ["type": "integer"],
          "category": ["type": "string", "enum": ["grammar", "spelling", "punctuation", "wordChoice", "style"]],
          "reason": ["type": "string"],
        ],
      ],
    ]
  ],
]

@main struct OpenAIRunner {
  static var model = ProcessInfo.processInfo.environment["MODEL"] ?? ""

  static func respondRetrying(model: String, instructions: String, input: [ChatMessage], schema: [String: Any]? = nil) async throws -> String {
    var last: Error?
    for attempt in 0..<3 {
      do { return try await respond(model: model, instructions: instructions, input: input, schema: schema) }
      catch { last = error; try await Task.sleep(for: .seconds(2 << attempt)) }
    }
    throw last!
  }

  static func intent(_ m: String) async throws -> Intent {
    let r = try await respondRetrying(model: model, instructions: intentInstructions, input: [ChatMessage(role: "user", text: "Message: \(m)")])
    return r.lowercased().contains("question") ? .question : .edit
  }

  static func explain(_ old: String, _ new: String) async throws -> [String] {
    let hs = hunks(old, new)
    guard !hs.isEmpty else { return [] }
    let list = hs.enumerated().map { "\($0.offset + 1). \"\($0.element.0)\" → \"\($0.element.1)\"" }.joined(separator: "\n")
    let raw = try await respondRetrying(
      model: model, instructions: explainInstructions,
      input: [ChatMessage(role: "user", text: "Original: \(old)\nCorrected: \(new)\nChanges:\n\(list)")], schema: explainSchema)
    let items = ((try? JSONSerialization.jsonObject(with: Data(raw.utf8))) as? [String: Any])?["items"] as? [[String: Any]] ?? []
    return hs.enumerated().map { k, h in
      let e = items.first { $0["id"] as? Int == k + 1 }
      return "[\(e?["category"] as? String ?? "?")] \(h.0) → \(h.1): \(e?["reason"] as? String ?? "?")"
    }
  }

  static func main() async throws {
    let args = Array(CommandLine.arguments.dropFirst())
    switch args.first ?? "run" {
    case "login":
      let c = try await signIn()
      print("Signed in as \(c.email ?? c.subject), client \(c.clientID)")
    case "models":
      for m in try await listModels() { print(m) }
    default:
      try await run(path: args.dropFirst().first ?? "cases.json")
    }
  }

  static func run(path: String) async throws {
    if model.isEmpty { model = try await listModels().first ?? "" }
    let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    print("model: \(model)\n")
    var passed = 0, total = 0
    for c in cases {
      print("━━ \(c.id) [\(c.contextType), \(c.level ?? "fluency")]")
      let session = CloudSession(model: model, instructions: fixInstructions(c))
      do {
        let t0 = Date()
        let fixed = clean(try await session.respond(to: firstPrompt(c)), original: c.text)
        let dt = Date().timeIntervalSince(t0)
        print("IN : \(c.text)\nOUT: \(fixed)")
        for l in (try? await explain(c.text, fixed)) ?? ["(explain failed)"] { print("   \(l)") }
        let f = check(fixed, original: c.text, c.expect, isAnswer: false)
        total += 1; if f.isEmpty { passed += 1 }
        print(String(format: "   %.1fs  ", dt) + (f.isEmpty ? "PASS" : "FAIL: " + f.joined(separator: "; ")))
        var latest = fixed
        for fu in c.followUps ?? [] {
          let t1 = Date()
          let isAnswer = try await intent(fu.message) == .question
          let prompt = isAnswer ? answerPrompt(fu.message) : revisionPrompt(fu.message)
          let raw = clean(try await session.respond(to: prompt), original: latest)
          print(">> \(fu.message)")
          if isAnswer { print("   ANSWER: \(raw)") } else {
            print("   OUT: \(raw)")
            for l in (try? await explain(latest, raw)) ?? ["(explain failed)"] { print("   \(l)") }
            latest = raw
          }
          let ff = check(raw, original: latest, fu.expect, isAnswer: isAnswer)
          total += 1; if ff.isEmpty { passed += 1 }
          print(String(format: "   %.1fs  ", Date().timeIntervalSince(t1)) + (ff.isEmpty ? "PASS" : "FAIL: " + ff.joined(separator: "; ")))
        }
      } catch {
        total += 1
        print("   ERROR: \(error)")
      }
      print("")
    }
    print("RESULT: \(passed) / \(total) checks passed")
  }
}
