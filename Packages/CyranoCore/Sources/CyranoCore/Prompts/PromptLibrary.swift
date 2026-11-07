// The prompts the user can edit in Settings → Prompts, stored over the built-in ones in
// prompts.json in Application Support. See docs/specs/02-tech-decisions.md M8 and 05-ui.md §5.

public import Foundation
public import Observation

/// A prompt the user can edit: a whole call's instructions, or a fragment the panel's options put
/// into the Proofread settings.
public enum EditablePrompt: Hashable, Sendable {
  case proofread
  case explainChanges
  case readContext
  case textType(TextType)
  case tone(Tone)
  case level(Level)

  /// In the order of Settings → Prompts: the calls in the order they run, then the fragments in
  /// the order of the panel's menus.
  public static let allCases: [EditablePrompt] =
    [.readContext, .proofread, .explainChanges] + TextType.allCases.map(textType)
    + Tone.allCases.map(tone) + Level.allCases.map(level)

  /// The prompt as the app has it built in (04 §4).
  var builtIn: String {
    switch self {
    case .proofread: Prompts.fixInstructions
    case .explainChanges: Prompts.explain
    case .readContext: Prompts.readContext
    case .textType(let type): Prompts.textType(type)
    case .tone(let tone): Prompts.tone(tone)
    case .level(let level): Prompts.level(level)
    }
  }

  /// The name in prompts.json: `proofread`, `tone.casual`.
  var key: String {
    switch self {
    case .proofread: "proofread"
    case .explainChanges: "explainChanges"
    case .readContext: "readContext"
    case .textType(let type): "textType.\(type.rawValue)"
    case .tone(let tone): "tone.\(tone.rawValue)"
    case .level(let level): "level.\(level.rawValue)"
    }
  }

  init?(key: String) {
    guard let prompt = Self.allCases.first(where: { $0.key == key }) else { return nil }
    self = prompt
  }
}

/// The prompts every call takes, the user's version over the built-in one. Only the prompts the
/// user changed are stored.
@MainActor @Observable
public final class PromptLibrary {
  private var edits: [EditablePrompt: String]
  private let file: URL?

  /// The built-in prompts, stored nowhere: what cyrano-eval checks.
  public init() {
    file = nil
    edits = [:]
  }

  /// Reads the file; without one every prompt is built in. A file that can't be read is kept
  /// next to it as `.bak`; prompts the app doesn't know are skipped.
  public init(file: URL) {
    self.file = file
    let stored = JSONFile.read([String: String].self, from: file) ?? [:]
    edits = Dictionary(
      uniqueKeysWithValues: stored.compactMap { key, text in
        EditablePrompt(key: key).map { ($0, text) }
      })
  }

  /// ~/Library/Application Support/Cyrano/prompts.json
  public static func standard() -> PromptLibrary {
    PromptLibrary(file: JSONFile.standard("prompts.json"))
  }

  public func text(_ prompt: EditablePrompt) -> String {
    edits[prompt] ?? prompt.builtIn
  }

  public func isModified(_ prompt: EditablePrompt) -> Bool {
    edits[prompt] != nil
  }

  /// Saves the user's version; the built-in text itself counts as no change.
  public func edit(_ prompt: EditablePrompt, to text: String) {
    edits[prompt] = text == prompt.builtIn ? nil : text
    guard let file else { return }
    JSONFile.write(
      Dictionary(uniqueKeysWithValues: edits.map { ($0.key.key, $0.value) }), to: file)
  }

  /// Restore Default.
  public func restore(_ prompt: EditablePrompt) {
    edit(prompt, to: prompt.builtIn)
  }
}
