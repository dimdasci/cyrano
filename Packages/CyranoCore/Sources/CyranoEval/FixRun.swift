// Runs every case through the panel's session — Fix, Explain, then the dialog — and prints a
// Markdown report of what the panel would show, with the criteria to judge it by.

import CyranoCore
import Foundation

struct CaseReport {
  let markdown: String
  /// A call failed, so the case did not run to the end.
  let failed: Bool
}

@MainActor
struct FixRun {
  let engine: any CorrectionEngine
  let models: ModelChoice

  /// True when every case ran without an error.
  func run(_ casesFile: URL) async throws -> Bool {
    let cases = try JSONDecoder().decode([FixCase].self, from: Data(contentsOf: casesFile))
    print("# Fix eval: \(models.proofreading.rawValue)\n")
    print(
      "\(Date.now.formatted(date: .abbreviated, time: .shortened)) · \(cases.count) cases · "
        + "explanations: \(models.explanations.rawValue)\n")
    var failed = 0
    for item in cases {
      let report = await report(item)
      print(report.markdown)
      if report.failed { failed += 1 }
    }
    print("---\n\n\(cases.count) cases, \(failed) with errors")
    return failed == 0
  }

  /// One case as one panel: the first check, then each dialog message in turn.
  func report(_ item: FixCase) async -> CaseReport {
    let dictionaryFile = URL.temporaryDirectory.appending(path: "cyrano-eval-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: dictionaryFile) }
    let dictionary = TermDictionary(file: dictionaryFile)
    for term in item.dictionary { dictionary.add(term) }
    let session = ProofreadingSession(
      original: item.text, context: item.context, options: item.options, models: models,
      engine: engine, dictionary: dictionary)
    var report = ReportWriter(session: session)
    report.header(item)
    guard await report.step(criteria: item.criteria, { await session.check() }) else {
      return report.finish(failed: true)
    }
    for turn in item.turns {
      guard await report.step(criteria: turn.criteria, { await session.send(turn.message) })
      else { return report.finish(failed: true) }
    }
    return report.finish(failed: false)
  }
}

/// Writes the feed of one session as it grows, step by step.
@MainActor
private struct ReportWriter {
  let session: ProofreadingSession
  private var lines: [String] = []
  /// Feed items already written.
  private var shown = 0

  init(session: ProofreadingSession) {
    self.session = session
  }

  mutating func header(_ item: FixCase) {
    let options = item.options
    lines.append("## \(item.id) · \(item.source.rawValue)\n")
    lines.append(
      [options.textType.title, options.tone.title, options.level.title, options.language.title]
        .joined(separator: " · "))
    if !options.customInstructions.isEmpty {
      lines.append("Custom instructions: \(Self.oneLine(options.customInstructions))")
    }
    if !item.context.isEmpty { lines.append("Context: \(Self.oneLine(item.context))") }
    if !item.dictionary.isEmpty {
      lines.append("Dictionary: \(item.dictionary.joined(separator: ", "))")
    }
    if let notes = item.notes { lines.append("Notes: \(notes)") }
    lines.append("\n**Text**\n\n" + Self.quoted(item.text))
  }

  /// Runs one call of the session and writes what it added to the feed. False when it failed.
  mutating func step(criteria: [String], _ action: () async -> Void) async -> Bool {
    let start = ContinuousClock.now
    await action()
    let elapsed = (ContinuousClock.now - start).formatted(
      .units(allowed: [.seconds], width: .narrow, fractionalPart: .show(length: 1)))
    for item in session.feed[shown...] { lines.append(Self.markdown(item)) }
    shown = session.feed.count
    if case .failed(let error) = session.activity {
      lines.append("**ERROR**: \(error) in \(elapsed)")
      return false
    }
    lines.append("_\(elapsed), \(session.tokens) tokens so far_")
    lines.append("\nCriteria:\n" + criteria.map { "- \($0)" }.joined(separator: "\n"))
    return true
  }

  func finish(failed: Bool) -> CaseReport {
    CaseReport(markdown: lines.joined(separator: "\n") + "\n", failed: failed)
  }

  private static func markdown(_ item: FeedItem) -> String {
    switch item {
    case .version(let version):
      "\n**Version \(version.number)** (\(origin(version.origin)))\n\n" + quoted(version.text)
        + "\n\n" + edit(version.edit)
    case .request(_, let text, let intent):
      "\n**Request** (\(intent == .question ? "question" : "edit")): \(text)"
    case .answer(_, let text):
      "\n**Answer**: \(text)"
    }
  }

  private static func edit(_ edit: Version.Edit) -> String {
    switch edit {
    case .translation(let language):
      return "Translated to \(language)"
    case .corrections(let diff, let explanations):
      if diff.changes.isEmpty { return "No changes" }
      let reasons: [Int: Explanation]
      if case .ready(let ready) = explanations { reasons = ready } else { reasons = [:] }
      return diff.changes.map { change in
        let words = change.words
        let reason = reasons[change.id].map { "\($0.category.rawValue): \($0.reason)" }
        return "\(change.id). \"\(words[0])\" → \"\(words[1])\" — \(reason ?? "NO EXPLANATION")"
      }.joined(separator: "\n")
    }
  }

  private static func origin(_ origin: Version.Origin) -> String {
    switch origin {
    case .check: "check"
    case .recheck: "recheck"
    case .request: "request"
    case .rejection: "rejection"
    }
  }

  /// Every line of the text kept as it is, as a quote.
  private static func quoted(_ text: String) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }
      .joined(separator: "\n")
  }

  private static func oneLine(_ text: String) -> String {
    text.split(whereSeparator: \.isNewline).joined(separator: " / ")
  }
}
