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
              .accessibilityLabel(
                modified ? String(localized: "\(prompt.title), Modified") : prompt.title)
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
    PromptGroup(
      title: String(localized: "Pipeline"), prompts: [.readContext, .proofread, .explainChanges]),
    PromptGroup(
      title: String(localized: "Text Types"),
      prompts: TextType.allCases.map(EditablePrompt.textType)),
    PromptGroup(title: String(localized: "Tones"), prompts: Tone.allCases.map(EditablePrompt.tone)),
    PromptGroup(
      title: String(localized: "Levels"), prompts: Level.allCases.map(EditablePrompt.level)),
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
    case .proofread: String(localized: "Proofread")
    case .explainChanges: String(localized: "Explain Changes")
    case .readContext: String(localized: "Read Context")
    case .textType(let type): type.title
    case .tone(let tone): tone.title
    case .level(let level): level.title
    }
  }

  /// What the prompt does, next to its title.
  fileprivate var role: String {
    switch self {
    case .proofread: String(localized: "Main instructions for every check and dialog message")
    case .explainChanges: String(localized: "Writes the reason for each change")
    case .readContext: String(localized: "Describes the conversation from a window screenshot")
    case .textType: String(localized: "Text type")
    case .tone: String(localized: "Tone")
    case .level: String(localized: "Level")
    }
  }

  /// What the app adds to the prompt and what stays fixed whatever it says (02 M8).
  fileprivate var note: String {
    switch self {
    case .proofread:
      String(
        localized: """
          The app adds # Settings after this text: the level, text type and tone chosen in the \
          panel, the output language and your custom instructions from Style. The text, context \
          and dictionary go in a separate message, and the reply format is set by the app.
          """)
    case .explainChanges:
      String(
        localized: """
          The app adds a line after this text: write every reason in the language of the \
          interface. It sends the original, the corrected text and the numbered changes. The \
          reply format, a category and a reason for each change, is set by the app.
          """)
    case .readContext:
      String(
        localized: """
          The app sends the window screenshot and your text. The reply format, the fields of \
          Context, is set by the app.
          """)
    case .textType:
      String(localized: "Added to # Settings in Proofread when this type is selected in the panel.")
    case .tone:
      String(localized: "Added to # Settings in Proofread when this tone is selected in the panel.")
    case .level:
      String(
        localized: "Added to # Settings in Proofread when this level is selected in the panel.")
    }
  }
}
