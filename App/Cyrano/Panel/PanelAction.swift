// Check or Send in the menu bar while a panel has the keyboard. See docs/specs/05-ui.md §2.9.

import SwiftUI

/// The label and state of the panel's one action button. Pressing it goes to `PanelModel.act`,
/// which reads the dialog field when pressed: SwiftUI keeps a menu item's action from when the
/// item last changed its label or state.
struct PanelAction {
  let title: String
  let isEnabled: Bool
}

/// Proofreading → Check or Send, ⌘↩, as Mail sends with ⌘↩. The one ⌘↩ of the panel: the button
/// by the dialog field has none of its own, so the key always goes through this item.
struct PanelActionCommands: Commands {
  let panel: PanelController

  var body: some Commands {
    CommandMenu("Proofreading") {
      let action = panel.keyModel?.action
      Button(action?.title ?? "Check") { panel.keyModel?.act() }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(action?.isEnabled != true)
    }
  }
}
