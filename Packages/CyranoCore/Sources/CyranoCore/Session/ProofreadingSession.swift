// One open panel: context read from the window, the first check, then a dialog of versions,
// requests and answers. The whole history is sent on every turn. See docs/specs/02 M3–M5, M10,
// C6 and 04-prompts.md §2.

public import Foundation
public import Observation

@MainActor @Observable
public final class ProofreadingSession {
  public enum Activity: Hashable, Sendable {
    case idle
    /// A new version streams: the first check, a recheck, or a dialog message the model answers
    /// with a version.
    case checking(partial: String)
    /// A dialog message is in the feed; its reply hasn't said its kind yet, or an answer streams.
    case replying(partial: String)
    case failed(EngineError)
  }

  /// What the one button by the dialog field does (05 §2.7).
  public enum Action: Hashable, Sendable {
    /// The first check, or a recheck with the changed context.
    case check
    /// A dialog message, with the current context.
    case send
  }

  /// The text to check; the user may edit it until the first check.
  public var original: String
  /// Who the text is for, what about, or the message it replies to; used from the next check on.
  /// Typing here stops reading it.
  public var context: String {
    didSet {
      if context != oldValue { stopReadingContext() }
    }
  }
  /// Reading the context from the window, or why it gave nothing; nil when there is nothing to
  /// say (02 C6).
  public private(set) var contextStatus: ContextStatus?
  /// PNG images of what the user is replying to; sent with the first message (M10).
  public var images: [Data] = []
  public var options: CheckOptions
  public let models: ModelChoice
  /// Terms found in the text go with every Fix request, so a new one counts from the next.
  public let dictionary: TermDictionary
  public private(set) var feed: [FeedItem] = []
  public private(set) var activity = Activity.idle
  /// Tokens spent in this panel, all calls together (M12).
  public private(set) var tokens = 0

  private let engine: any CorrectionEngine
  private var nextID = 1
  private var retry: (@MainActor () async -> Void)?
  /// The context as it went out in the last Fix request.
  private var sentContext: (text: String, images: [Data])?
  private var contextReading: Task<String, any Error>?
  /// The window as it was when the panel opened, for Try Again after a failed read.
  private var contextScreenshot: Data?

  public init(
    original: String, context: String = "", options: CheckOptions,
    models: ModelChoice = ModelChoice(), engine: any CorrectionEngine, dictionary: TermDictionary
  ) {
    self.original = original
    self.context = context
    self.options = options
    self.models = models
    self.engine = engine
    self.dictionary = dictionary
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

  /// Check waits while the context is read.
  public var isBusy: Bool {
    switch activity {
    case .checking, .replying: true
    case .idle, .failed: isReadingContext
    }
  }

  /// Check until the first version, and again when the context changed and there is no message.
  public func action(for message: String) -> Action {
    if versions.isEmpty { return .check }
    return contextChanged && message.trimmed.isEmpty ? .check : .send
  }

  public func canPerform(message: String) -> Bool {
    guard !isBusy else { return false }
    return switch action(for: message) {
    case .check: !latestText.trimmed.isEmpty
    case .send: !message.trimmed.isEmpty
    }
  }

  public func perform(message: String) async {
    switch action(for: message) {
    case .check: await check()
    case .send: await send(message)
    }
  }

  private var contextChanged: Bool {
    guard let sentContext else { return true }
    return sentContext.text != context || sentContext.images != images
  }

  /// The first check, or a recheck of the latest version after settings or context changed.
  public func check() async {
    let origin: Version.Origin = versions.isEmpty ? .check : .recheck
    stopReadingContext()
    retry = { [weak self] in await self?.check() }
    activity = .checking(partial: "")
    do {
      let reply: FixReply<CheckKind> = try await fix(prompt: userPrompt(for: origin)) {
        .checking(partial: $1)
      }
      await addVersion(reply.text, origin: origin)
    } catch {
      fail(error)
    }
  }

  /// A dialog turn: the model judges what the author wants and answers or writes a new version.
  public func send(_ message: String) async {
    let message = message.trimmed
    guard !message.isEmpty else { return }
    retry = { [weak self] in await self?.send(message) }
    let request = FeedItem.request(id: takeID(), text: message)
    feed.append(request)
    activity = .replying(partial: "")
    do {
      let reply: FixReply<DialogKind> = try await fix(prompt: nil) { kind, text in
        kind == .version ? .checking(partial: text) : .replying(partial: text)
      }
      switch reply.kind {
      case .version: await addVersion(reply.text, origin: .request)
      case .answer: addAnswer(reply.text)
      }
    } catch {
      feed.removeAll { $0 == request }
      fail(error)
    }
  }

  public func tryAgain() async {
    await retry?()
  }

  private func addAnswer(_ text: String) {
    feed.append(.answer(id: takeID(), text: text))
    activity = .idle
    retry = nil
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
    let call = ExplainCall.call(model: models.explanations, old: old, diff: diff)
    if let output = try? await run(call),
      let parsed = try? ExplainCall.parse(output, diff: diff)
    {
      explanations = .ready(parsed)
    }
    guard let index = feed.firstIndex(of: .version(version)) else { return }
    var updated = version
    updated.edit = .corrections(diff, explanations)
    feed[index] = .version(updated)
  }

  /// Runs Fix over the history plus an optional new user prompt, streaming the reply's text into
  /// `activity` as soon as its kind is known.
  private func fix<Kind: ReplyKind>(
    prompt: ChatMessage?, progress: @escaping (Kind?, String) -> Activity
  ) async throws -> FixReply<Kind> {
    let input = history() + (prompt.map { [$0] } ?? [])
    let call = ModelCall(
      model: models.proofreading, instructions: Prompts.proofreadInstructions(options),
      input: input, schema: FixReply<Kind>.schema)
    let sent = (text: context, images: images)
    var partial = PartialReply()
    let output = try await run(call) { delta in
      partial.append(delta)
      self.activity = progress(partial.kind.flatMap(Kind.init(rawValue:)), partial.text)
    }
    guard let reply = FixReply<Kind>(output: output) else {
      throw EngineError.failed("The reply was not the fields asked for.")
    }
    sentContext = sent
    let text = Prompts.restoringTags(Prompts.cleanOutput(reply.text, original: latestText))
    return FixReply(kind: reply.kind, text: text)
  }

  /// Streams the call, handing each delta to `progress`; returns the whole output.
  private func run(
    _ call: ModelCall, progress: ((String) -> Void)? = nil
  ) async throws -> String {
    for try await update in engine.respond(call) {
      switch update {
      case .delta(let delta):
        progress?(delta)
      case .completed(let text, let tokens):
        self.tokens += tokens
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
        let stored = Prompts.stored(version: version.text, number: version.number)
        return prompt + [ChatMessage(.assistant, stored)]
      case .request(_, let text):
        return [ChatMessage(.user, text)]
      case .answer(_, let text):
        return [ChatMessage(.assistant, Prompts.stored(answer: text))]
      }
    }
  }

  /// The first message always carries the current context and images, so a recheck sees them.
  private func userPrompt(for origin: Version.Origin) -> ChatMessage? {
    switch origin {
    case .check:
      ChatMessage(
        .user,
        Prompts.firstMessage(
          text: original, context: context, keep: dictionary.found(in: original),
          spell: dictionary.misspelled(in: original)),
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

/// Edits made in the panel without calling the model.
extension ProofreadingSession {
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

  /// Rejects the change and adds one of its replaced words to the dictionary: one action
  /// (05 §2.4). Returns whether the term is new to the dictionary.
  @discardableResult
  public func neverChange(_ change: Change, keeping term: String) -> Bool {
    guard change.terms.contains(term) else { return false }
    reject(change)
    return dictionary.add(term)
  }
}

/// Context read from a screenshot of the window before the first check (02 C6).
extension ProofreadingSession {
  public var isReadingContext: Bool {
    if case .reading = contextStatus { true } else { false }
  }

  /// Fills Context with who the text is for, what about and in which language, read from a
  /// screenshot of the window, and sets the output language to the conversation's unless the
  /// user chose one (02 M7). Otherwise `contextStatus` says why Context stays empty.
  public func readContext(from screenshot: Data, timeout: Duration = .seconds(20)) async {
    stopReadingContext()
    contextScreenshot = screenshot
    contextStatus = .reading(since: Date())
    let call = ModelCall.readContext(screenshot: screenshot, draft: original, model: models.context)
    let reading = Task { try await run(call) }
    contextReading = reading
    let timer = Task {
      do { try await Task.sleep(for: timeout) } catch { return false }
      reading.cancel()
      return true
    }
    let result = await reading.result
    timer.cancel()
    let timedOut = await timer.value
    // Skipped, typed over or read again meanwhile: that already set the status.
    guard contextReading == reading else { return }
    contextReading = nil
    finishReading(result, timedOut: timedOut)
  }

  /// Try Again after a failed read: the same screenshot, read again.
  public func readContextAgain() async {
    guard let contextScreenshot else { return }
    await readContext(from: contextScreenshot)
  }

  /// Skip: stops the call, and the check goes without the context.
  public func stopReadingContext() {
    contextReading?.cancel()
    contextReading = nil
    contextScreenshot = nil
    contextStatus = nil
  }

  private func finishReading(_ result: Result<String, any Error>, timedOut: Bool) {
    switch result {
    case .success(let answer):
      guard let read = ConversationContext(answer: answer) else {
        contextStatus = .failed(.failed("The answer was not the fields asked for."))
        return
      }
      context = read.text
      if let language = read.language, options.language == .sameAsText {
        options.language = language
      }
      contextStatus = read.text.isEmpty ? .nothingFound : nil
    case .failure where timedOut:
      contextStatus = .timedOut
    case .failure(let error):
      contextStatus = .failed(error as? EngineError ?? .failed(String(describing: error)))
    }
  }
}
