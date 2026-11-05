// Runs Cyrano's prompts on eval cases with the same code as the app. See docs/specs/04-prompts.md §5.
//
//   cyrano-eval fix <cases.json> [model]       checks each case and its dialog, prints a report
//   cyrano-eval context <cases.json> [model]   reads the context of each case and checks it
//   cyrano-eval render <cases.json> <folder>   writes each case's window as a PNG
//
// Signs in with Cyrano's Keychain item: the first run asks to allow access to it.

import CyranoCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

/// The model named after the cases file, or the app's default for the operation.
func model(or fallback: Model) -> Model {
  guard arguments.count > 2 else { return fallback }
  guard let model = Model(rawValue: arguments[2]) else {
    print("unknown model \(arguments[2])")
    exit(2)
  }
  return model
}

/// The ChatGPT plan signed in as in the app.
func signedInEngine() -> OpenAIEngine {
  let auth = AuthService()
  return OpenAIEngine(transport: URLSessionTransport()) { try await auth.accessToken() }
}

switch (arguments.first, arguments.count) {
case ("fix", 2...3):
  let model = model(or: ModelChoice().proofreading)
  let ran = try await FixRun(
    engine: signedInEngine(), models: ModelChoice(proofreading: model, explanations: model)
  ).run(URL(filePath: arguments[1]))
  exit(ran ? 0 : 1)
case ("context", 2...3):
  let passed = try await ContextRun(
    engine: signedInEngine(), model: model(or: ModelChoice().context)
  )
  .run(URL(filePath: arguments[1]))
  exit(passed ? 0 : 1)
case ("render", 3):
  try await renderWindows(URL(filePath: arguments[1]), to: URL(filePath: arguments[2]))
default:
  let models = Model.allCases.map(\.rawValue).joined(separator: "|")
  print("usage: cyrano-eval fix <cases.json> [\(models)]")
  print("       cyrano-eval context <cases.json> [\(models)]")
  print("       cyrano-eval render <cases.json> <folder>")
  exit(2)
}
