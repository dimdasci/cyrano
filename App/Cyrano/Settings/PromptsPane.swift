// Settings → Prompts: the instructions the app sends to the model, editable over the built-in
// ones, with Restore Default. See docs/specs/05-ui.md §5 and 02-tech-decisions.md M8.

import CyranoCore
import SwiftUI

struct PromptsPane: View {
  let prompts: PromptLibrary
  @State private var selected = EditablePrompt.proofread

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        list
        // VoiceOver hears "Modified" on the row itself.
        Text("• Modified")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      .frame(width: 170)
      PromptEditor(prompt: selected, prompts: prompts)
    }
    .padding(20)
    .frame(height: 420)
  }

  private var list: some View {
    // A click on the selected row doesn't leave the editor without a prompt.
    let selection = Binding<EditablePrompt?>(
      get: { selected }, set: { if let prompt = $0 { selected = prompt } })
    return List(selection: selection) {
      ForEach(PromptGroup.all, id: \.title) { group in
        Section(group.title) {
          ForEach(group.prompts, id: \.self) { prompt in
            let modified = prompts.isModified(prompt)
            // One label: VoiceOver reads a row by its value alone and would drop the name.
            Text(prompt.title + (modified ? " •" : ""))
              .accessibilityLabel(prompt.title + (modified ? ", Modified" : ""))
          }
        }
      }
    }
    .accessibilityLabel("Prompts")
  }
}

/// The list's sections: whole calls in the order they run, then the fragments in the order of
/// the panel's menus.
private struct PromptGroup {
  let title: String
  let prompts: [EditablePrompt]

  static let all = [
    PromptGroup(title: "Pipeline", prompts: [.readContext, .proofread, .explainChanges]),
    PromptGroup(title: "Text Types", prompts: TextType.allCases.map(EditablePrompt.textType)),
    PromptGroup(title: "Tones", prompts: Tone.allCases.map(EditablePrompt.tone)),
    PromptGroup(title: "Levels", prompts: Level.allCases.map(EditablePrompt.level)),
  ]
}

/// The selected prompt's text; every edit is saved at once.
private struct PromptEditor: View {
  let prompt: EditablePrompt
  let prompts: PromptLibrary

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(prompt.title).font(.headline)
        Text(prompt.role).font(.caption).foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .combine)
      TextEditor(
        text: Binding(get: { prompts.text(prompt) }, set: { prompts.edit(prompt, to: $0) })
      )
      .font(.system(.callout, design: .monospaced))
      .scrollContentBackground(.hidden)
      .padding(6)
      .background(.background, in: .rect(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
      .accessibilityLabel("\(prompt.title) prompt")
      Text(prompt.note)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        Text("Changes apply to the next check.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Restore Default") { prompts.restore(prompt) }
          .disabled(!prompts.isModified(prompt))
      }
    }
  }
}

extension EditablePrompt {
  fileprivate var title: String {
    switch self {
    case .proofread: "Proofread"
    case .explainChanges: "Explain Changes"
    case .readContext: "Read Context"
    case .textType(let type): type.title
    case .tone(let tone): tone.title
    case .level(let level): level.title
    }
  }

  /// What the prompt does, next to its title.
  fileprivate var role: String {
    switch self {
    case .proofread: "Main instructions for every check and dialog message"
    case .explainChanges: "Writes the reason for each change"
    case .readContext: "Describes the conversation from a window screenshot"
    case .textType: "Text type"
    case .tone: "Tone"
    case .level: "Level"
    }
  }

  /// What the app adds to the prompt and what stays fixed whatever it says (02 M8).
  fileprivate var note: String {
    switch self {
    case .proofread:
      "The app adds # Settings after this text: the level, text type and tone chosen in the "
        + "panel, the output language and your custom instructions from Style. The text, context "
        + "and dictionary go in a separate message, and the reply format is set by the app."
    case .explainChanges:
      "The app sends the original, the corrected text and the numbered changes. The reply "
        + "format, a category and a reason for each change, is set by the app."
    case .readContext:
      "The app sends the window screenshot and your text. The reply format, the fields of "
        + "Context, is set by the app."
    case .textType:
      "Added to # Settings in Proofread when this type is selected in the panel."
    case .tone:
      "Added to # Settings in Proofread when this tone is selected in the panel."
    case .level:
      "Added to # Settings in Proofread when this level is selected in the panel."
    }
  }
}
