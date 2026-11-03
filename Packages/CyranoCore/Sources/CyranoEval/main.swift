// Runs Cyrano's prompts on eval cases with the same code as the app. See docs/specs/04-prompts.md §5.
//
//   cyrano-eval context <cases.json> [model]   reads the context of each case and checks it
//   cyrano-eval render <cases.json> <folder>   writes each case's window as a PNG
//
// Signs in with Cyrano's Keychain item: the first run asks to allow access to it.

import CyranoCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
switch (arguments.first, arguments.count) {
case ("context", 2...3):
  guard let model = arguments.count > 2 ? Model(rawValue: arguments[2]) : ModelChoice().context
  else {
    print("unknown model \(arguments[2])")
    exit(2)
  }
  let auth = AuthService()
  let engine = OpenAIEngine(transport: URLSessionTransport()) { try await auth.accessToken() }
  let passed = try await ContextRun(engine: engine, model: model).run(URL(filePath: arguments[1]))
  exit(passed ? 0 : 1)
case ("render", 3):
  try await renderWindows(URL(filePath: arguments[1]), to: URL(filePath: arguments[2]))
default:
  let models = Model.allCases.map(\.rawValue).joined(separator: "|")
  print("usage: cyrano-eval context <cases.json> [\(models)]")
  print("       cyrano-eval render <cases.json> <folder>")
  exit(2)
}
