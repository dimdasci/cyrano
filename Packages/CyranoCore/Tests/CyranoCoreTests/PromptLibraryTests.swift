import Foundation
import Testing

@testable import CyranoCore

/// A prompts file in a new temporary folder that does not exist yet.
private func temporaryPromptsFile() -> URL {
  FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString)
    .appending(path: "prompts.json")
}

private func write(_ text: String, to file: URL) throws {
  try FileManager.default.createDirectory(
    at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
  try Data(text.utf8).write(to: file)
}

/// The user's prompts over the built-in ones, in prompts.json (02 M8, 05 §5).
@MainActor @Suite struct PromptLibraryTests {
  @Test func anEditIsReadBackAndMarkedModified() {
    let file = temporaryPromptsFile()
    PromptLibrary(file: file).edit(.tone(.casual), to: "Tone: relaxed.")

    let library = PromptLibrary(file: file)
    #expect(library.text(.tone(.casual)) == "Tone: relaxed.")
    #expect(library.isModified(.tone(.casual)))
    #expect(!library.isModified(.tone(.neutral)))
  }

  @Test func theFileHoldsOnlyModifiedPrompts() throws {
    let file = temporaryPromptsFile()
    let library = PromptLibrary(file: file)
    library.edit(.explainChanges, to: "Explain briefly.")
    library.edit(.level(.rewrite), to: "Rewrite freely.")
    library.edit(.proofread, to: library.text(.proofread))

    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
    let stored = try #require(json as? [String: String])
    #expect(stored == ["explainChanges": "Explain briefly.", "level.rewrite": "Rewrite freely."])
  }

  @Test func restoreDefaultBringsBackTheBuiltInPrompt() {
    let file = temporaryPromptsFile()
    let builtIn = PromptLibrary().text(.readContext)
    PromptLibrary(file: file).edit(.readContext, to: "Describe the chat.")

    PromptLibrary(file: file).restore(.readContext)
    let library = PromptLibrary(file: file)
    #expect(library.text(.readContext) == builtIn)
    #expect(!library.isModified(.readContext))
  }

  @Test func withoutAFileEveryPromptIsBuiltIn() {
    let library = PromptLibrary(file: temporaryPromptsFile())
    #expect(EditablePrompt.allCases.allSatisfy { !library.isModified($0) })
    #expect(library.text(.tone(.neutral)) == "Tone: neutral.")
  }

  @Test func anUnreadableFileIsKeptAside() throws {
    let file = temporaryPromptsFile()
    try write("Be brief.", to: file)

    let library = PromptLibrary(file: file)
    #expect(!library.isModified(.proofread))
    let backup = file.appendingPathExtension("bak")
    #expect(try String(contentsOf: backup, encoding: .utf8) == "Be brief.")
  }

  @Test func unknownPromptsInTheFileAreSkipped() throws {
    let file = temporaryPromptsFile()
    try write(#"{"classifier": "Old.", "tone.casual": "Tone: relaxed."}"#, to: file)

    let library = PromptLibrary(file: file)
    #expect(library.text(.tone(.casual)) == "Tone: relaxed.")
  }

  @Test func everyPromptHasItsOwnKeyInTheFile() {
    let keys = Set(EditablePrompt.allCases.map(\.key))
    let parsed = EditablePrompt.allCases.compactMap { EditablePrompt(key: $0.key) }
    #expect(keys.count == 3 + 3 + 5 + 3)
    #expect(parsed == EditablePrompt.allCases)
  }
}

/// What an edited prompt does to the next call (02 M8).
@MainActor @Suite struct EditedPromptTests {
  func checked(
    _ edits: [EditablePrompt: String], options: CheckOptions = CheckOptions()
  ) async -> FakeEngine {
    let prompts = PromptLibrary(file: temporaryPromptsFile())
    for (prompt, text) in edits { prompts.edit(prompt, to: text) }
    let engine = FakeEngine(fixes: ["I have a cat."])
    let session = ProofreadingSession(
      original: "I has a cat.", options: options, engine: engine, dictionary: dictionary(),
      prompts: prompts)
    await session.readContext(from: imageA)
    await session.check()
    return engine
  }

  @Test func anEditedProofreadPromptIsFollowedByTheSettings() async throws {
    let engine = await checked(
      [.proofread: "Fix typos only."], options: CheckOptions(tone: .casual))
    let call = try #require(engine.fixCalls.first)
    let settings = call.instructions.components(separatedBy: "\n- ")
    #expect(call.instructions.hasPrefix("Fix typos only.\n\n# Settings\n- "))
    #expect(settings.contains(PromptLibrary().text(.tone(.casual))))
    #expect(call.schema == FixReply<CheckKind>.schema)
  }

  /// A fragment is one line of the settings; lines of its own become lines of the list.
  @Test func anEditedFragmentReplacesItsLine() async throws {
    let edits: [EditablePrompt: String] = [.level(.fluency): "Fix errors.\n\nKeep it short."]
    let engine = await checked(edits)
    let call = try #require(engine.fixCalls.first)
    #expect(call.instructions.contains("# Settings\n- Fix errors.\n- Keep it short.\n- This is"))
  }

  @Test func editedExplainAndContextPromptsGoToTheirCalls() async {
    let engine = await checked([.explainChanges: "Say why.", .readContext: "Who is it for?"])
    let explain = engine.calls.first { $0.schema == ExplainCall.schema }
    #expect(explain?.instructions == "Say why.")
    #expect(engine.contextCalls.first?.instructions == "Who is it for?")
  }
}
