// One open panel: the first check, then a dialog of versions, requests and answers.
// The whole history is sent on every turn. See docs/specs/02 M3–M5, M10 and 04-prompts.md §2.

public import Foundation
public import Observation

@MainActor @Observable
public final class ProofreadingSession {
  public enum Activity: Hashable, Sendable {
    case idle
    case checking(partial: String)
    /// A dialog message waits for its kind; it is not in the feed yet.
    case classifying(request: String)
    /// The message is in the feed; its answer or new version streams.
    case replying(partial: String)
    case failed(EngineError)
  }

  public let original: String
  /// What the user is replying to; used from the next check on.
  public var context: String
  /// PNG images of what the user is replying to; sent with the first message (M10).
  public var images: [Data] = []
  public var options: CheckOptions
  public private(set) var feed: [FeedItem] = []
  public private(set) var activity = Activity.idle
  public private(set) var usage = TokenUsage()

  private let engine: any CorrectionEngine
  private var nextID = 1
  private var retry: (@MainActor () async -> Void)?

  public init(
    original: String, context: String = "", options: CheckOptions, engine: any CorrectionEngine
  ) {
    self.original = original
    self.context = context
    self.options = options
    self.engine = engine
  }

  public var versions: [Version] {
    feed.compactMap { item in
      guard case .version(let version) = item else { return nil }
      return version
    }
  }

  public var latestText: String { versions.last?.text ?? original }

  /// Many images make a check slower and use more of the plan limit (M10).
  public var hasManyImages: Bool { images.count > 10 }

  public var isBusy: Bool {
    switch activity {
    case .checking, .classifying, .replying: true
    case .idle, .failed: false
    }
  }

  /// The first check, or a recheck of the latest version after settings or context changed.
  public func check() async {
    let origin: Version.Origin = versions.isEmpty ? .check : .recheck
    retry = { await self.check() }
    activity = .checking(partial: "")
    do {
      let text = try await fix(prompt: userPrompt(for: origin)) { .checking(partial: $0) }
      await addVersion(text, origin: origin)
    } catch {
      fail(error)
    }
  }

  /// A dialog turn: a question gets an answer, anything else a new version.
  public func send(_ message: String) async {
    let message = message.trimmed
    guard !message.isEmpty else { return }
    retry = { await self.send(message) }
    activity = .classifying(request: message)
    do {
      let intent = try await classify(message)
      let request = FeedItem.request(id: takeID(), text: message, intent: intent)
      feed.append(request)
      activity = .replying(partial: "")
      do {
        let text = try await fix(prompt: nil) { .replying(partial: $0) }
        try await finishTurn(text, intent: intent)
      } catch {
        feed.removeAll { $0 == request }
        throw error
      }
    } catch {
      fail(error)
    }
  }

  public func tryAgain() async {
    await retry?()
  }

  /// Reverts one change of the latest version into a new version, without calling the model.
  public func reject(_ change: Change) {
    guard let latest = versions.last, let diff = latest.diff, diff.changes.contains(change) else {
      return
    }
    let text = diff.text(rejecting: change)
    feed.append(
      .version(
        Version(
          number: latest.number + 1, text: text,
          edit: .corrections(TextDiff(old: latest.text, new: text), .unavailable),
          origin: .rejection)))
  }

  private func finishTurn(_ text: String, intent: Intent) async throws {
    switch intent {
    case .question:
      feed.append(.answer(id: takeID(), text: text))
      activity = .idle
    case .edit:
      await addVersion(text, origin: .request)
    }
  }

  private func addVersion(_ text: String, origin: Version.Origin) async {
    let previous = latestText
    let version = Version(
      number: versions.count + 1, text: text, edit: edit(from: previous, to: text), origin: origin)
    feed.append(.version(version))
    activity = .idle
    retry = nil
    guard case .corrections(let diff, .pending) = version.edit else { return }
    await explain(version, diff: diff, old: previous)
  }

  private func edit(from previous: String, to text: String) -> Version.Edit {
    if let language = Language.translation(from: previous, to: text) {
      return .translation(into: language)
    }
    let diff = TextDiff(old: previous, new: text)
    return .corrections(diff, diff.changes.isEmpty ? .ready([:]) : .pending)
  }

  private func explain(_ version: Version, diff: TextDiff, old: String) async {
    var explanations = Version.Explanations.unavailable
    if let output = try? await run(ExplainCall.call(old: old, diff: diff), count: \.explain),
      let parsed = try? ExplainCall.parse(output, diff: diff)
    {
      explanations = .ready(parsed)
    }
    guard let index = feed.firstIndex(of: .version(version)) else { return }
    var updated = version
    updated.edit = .corrections(diff, explanations)
    feed[index] = .version(updated)
  }

  private func classify(_ message: String) async throws -> Intent {
    let call = ModelCall(
      instructions: Prompts.classify, input: [ChatMessage(.user, "Message: \(message)")])
    let output = try await run(call, count: \.intent)
    return output.lowercased().contains("question") ? .question : .edit
  }

  /// Runs Fix over the history plus an optional new user prompt, streaming into `activity`.
  private func fix(
    prompt: ChatMessage?, progress: @escaping (String) -> Activity
  ) async throws -> String {
    let input = history() + (prompt.map { [$0] } ?? [])
    let call = ModelCall(
      instructions: Prompts.proofreadInstructions(options), input: input)
    let output = try await run(call, count: \.fix) { self.activity = progress($0) }
    return Prompts.cleanOutput(output, original: latestText)
  }

  private func run(
    _ call: ModelCall, count: WritableKeyPath<TokenUsage, Int>,
    progress: ((String) -> Void)? = nil
  ) async throws -> String {
    var partial = ""
    for try await update in engine.respond(call) {
      switch update {
      case .delta(let delta):
        partial += delta
        progress?(partial)
      case .completed(let text, let tokens):
        usage[keyPath: count] += tokens
        return text
      }
    }
    throw EngineError.failed("The response ended before it was complete.")
  }

  private func history() -> [ChatMessage] {
    feed.flatMap { item -> [ChatMessage] in
      switch item {
      case .version(let version):
        let prompt = userPrompt(for: version.origin).map { [$0] } ?? []
        return prompt + [ChatMessage(.assistant, version.text)]
      case .request(_, let text, .edit):
        return [ChatMessage(.user, Prompts.revision(text, language: options.language))]
      case .request(_, let text, .question):
        return [ChatMessage(.user, Prompts.question(text))]
      case .answer(_, let text):
        return [ChatMessage(.assistant, text)]
      }
    }
  }

  /// The first message always carries the current context and images, so a recheck sees them.
  private func userPrompt(for origin: Version.Origin) -> ChatMessage? {
    switch origin {
    case .check:
      ChatMessage(
        .user, Prompts.firstMessage(text: original, context: context, hasImages: !images.isEmpty),
        images: images)
    case .recheck: ChatMessage(.user, Prompts.recheck)
    case .request, .rejection: nil
    }
  }

  private func fail(_ error: any Error) {
    activity = .failed(error as? EngineError ?? .failed(String(describing: error)))
  }

  private func takeID() -> Int {
    defer { nextID += 1 }
    return nextID
  }
}
