// «Check Text…»: paste text, then the same feed as the panel.
// See docs/specs/05-ui.md §3.

import CyranoCore
import SwiftUI

struct ManualCheckView: View {
  let app: AppModel
  @State private var text = ""
  @State private var panel: PanelModel?

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .bottom) {
        TextEditor(text: $text)
          .font(.body)
          .frame(height: 90)
          .overlay(alignment: .topLeading) {
            if text.isEmpty {
              Text("Paste text to check").foregroundStyle(.tertiary).padding(.leading, 5)
                .allowsHitTesting(false)
            }
          }
        Button("Check", action: check)
          .keyboardShortcut(.return, modifiers: .command)
          .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding(12)
      Divider()
      if let panel {
        ProofreadingView(model: panel)
      } else {
        Spacer()
      }
    }
    .frame(minWidth: 520, minHeight: 480)
  }

  private func check() {
    let captured = TextCapture.manual(text)
    let session = app.makeSession(for: captured)
    panel = PanelModel(content: .session(session, captured), app: app)
    Task { await session.check() }
  }
}
