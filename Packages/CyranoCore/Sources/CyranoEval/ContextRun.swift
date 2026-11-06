// Reads the context of every case and prints it with the result of its checks.

import CyranoCore
import Foundation

@MainActor
struct ContextRun {
  let engine: any CorrectionEngine
  let model: Model

  /// True when every case passed.
  func run(_ casesFile: URL) async throws -> Bool {
    let cases = try JSONDecoder().decode([ContextCase].self, from: Data(contentsOf: casesFile))
    print("model: \(model.rawValue)\n")
    var passed = 0
    for item in cases {
      print("━━ \(item.id)")
      do {
        let screenshot = try await item.screenshot(in: casesFile.deletingLastPathComponent())
        let start = ContinuousClock.now
        let session = await read(screenshot: screenshot, draft: item.text)
        if let error = Self.error(session.contextStatus) {
          print("   ERROR: \(error) in \(seconds(since: start))")
          print("")
          continue
        }
        let failures = item.expect.failures(in: session.context)
        if failures.isEmpty { passed += 1 }
        print(session.context.isEmpty ? "(no context)" : session.context)
        print("Output language: \(session.options.language.title)")
        print(
          "   \(seconds(since: start)), \(session.tokens) tokens  "
            + (failures.isEmpty ? "PASS" : "FAIL: " + failures.joined(separator: "; ")))
      } catch {
        print("   ERROR: \(error)")
      }
      print("")
    }
    print("RESULT: \(passed) / \(cases.count) cases passed")
    return passed == cases.count
  }

  /// Context reading does not use the dictionary; this file is never written.
  private static let noDictionary = URL.temporaryDirectory.appending(path: "cyrano-eval-terms.json")

  /// No answer came: the case has nothing to check.
  private static func error(_ status: ContextStatus?) -> String? {
    switch status {
    case .timedOut: "timed out"
    case .failed(let error): String(describing: error)
    case .reading, .nothingFound, nil: nil
    }
  }

  /// Reads the context as the panel does, with a longer timeout so a slow answer still shows.
  private func read(screenshot: Data, draft: String) async -> ProofreadingSession {
    let session = ProofreadingSession(
      original: draft, options: CheckOptions(), models: ModelChoice(context: model),
      engine: engine, dictionary: TermDictionary(file: Self.noDictionary))
    await session.readContext(from: screenshot, timeout: .seconds(60))
    return session
  }

  private func seconds(since start: ContinuousClock.Instant) -> String {
    (ContinuousClock.now - start).inSeconds
  }
}

/// Writes the window of every case as a PNG, to look at it as the model does.
@MainActor
func renderWindows(_ casesFile: URL, to folder: URL) async throws {
  let cases = try JSONDecoder().decode([ContextCase].self, from: Data(contentsOf: casesFile))
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for item in cases {
    let png = try await item.screenshot(in: casesFile.deletingLastPathComponent())
    try png.write(to: folder.appending(path: "\(item.id).png"))
    print(folder.appending(path: "\(item.id).png").path)
  }
}
