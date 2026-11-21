// Runs Cyrano's prompts on eval cases with the same code as the app. See docs/specs/04-prompts.md §5.
//
//   cyrano-eval fix <cases.json> [model] [explanation model] [en|es|ru]
//                                              checks each case and its dialog, prints a report;
//                                              the reasons are in the interface language given,
//                                              English by default
//   cyrano-eval context <cases.json> [model]   reads the context of each case and checks it
//   cyrano-eval render <cases.json> <folder>   writes each case's window as a PNG
//
// Signs in with Cyrano's Keychain item: the first run asks to allow access to it.

import CyranoCore
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

/// The model named at this argument, or the fallback when there is none.
func model(at index: Int = 2, or fallback: Model) -> Model {
  guard arguments.count > index else { return fallback }
  guard let model = Model(rawValue: arguments[index]) else {
    print("unknown model \(arguments[index])")
    exit(2)
  }
  return model
}

/// The ChatGPT plan signed in as in the app.
func signedInEngine() -> OpenAIEngine {
  let auth = AuthService()
  return OpenAIEngine(transport: URLSessionTransport()) { try await auth.accessToken() }
}

/// The interface language named at this argument, English when there is none: the report is
/// the same whatever language the Mac is in.
func interfaceLanguage(at index: Int) -> InterfaceLanguage {
  let code = arguments.count > index ? arguments[index] : "en"
  let language = InterfaceLanguage(preferences: [code])
  guard language.code == code else {
    print("unknown interface language \(code)")
    exit(2)
  }
  return language
}

switch (arguments.first, arguments.count) {
case ("fix", 2...5):
  let check = model(or: ModelChoice().proofreading)
  let models = ModelChoice(proofreading: check, explanations: model(at: 3, or: check))
  let ran = try await FixRun(
    engine: signedInEngine(), models: models, language: interfaceLanguage(at: 4)
  )
  .run(URL(filePath: arguments[1]))
  exit(ran ? 0 : 1)
case ("context", 2...3):
  // The report reads the same whatever language the Mac is in.
  let passed = try await InterfaceLanguage.$current.withValue(
    InterfaceLanguage(preferences: ["en"])
  ) {
    try await ContextRun(engine: signedInEngine(), model: model(or: ModelChoice().context))
      .run(URL(filePath: arguments[1]))
  }
  exit(passed ? 0 : 1)
case ("render", 3):
  try await renderWindows(URL(filePath: arguments[1]), to: URL(filePath: arguments[2]))
default:
  let models = Model.allCases.map(\.rawValue).joined(separator: "|")
  print("usage: cyrano-eval fix <cases.json> [\(models)] [\(models)] [en|es|ru]")
  print("       cyrano-eval context <cases.json> [\(models)]")
  print("       cyrano-eval render <cases.json> <folder>")
  exit(2)
}
