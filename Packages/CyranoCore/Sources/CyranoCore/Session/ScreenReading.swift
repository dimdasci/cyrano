// Reading the draft from a screenshot when neither Accessibility nor the clipboard give text.
// See docs/specs/02 C2.

public import Foundation

public enum ScreenReading {
  /// The text the user is writing in the screenshot (PNG), or nil if there is none.
  public static func draft(in screenshot: Data, engine: any CorrectionEngine) async throws
    -> String?
  {
    let call = ModelCall(
      instructions: Prompts.readScreen,
      input: [ChatMessage(.user, "Screenshot:", images: [screenshot])])
    var text = ""
    for try await update in engine.respond(call) {
      if case .completed(let output, _) = update { text = output }
    }
    let draft = text.trimmed
    return draft.isEmpty ? nil : draft
  }
}
