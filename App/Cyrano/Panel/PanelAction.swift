// Check or Send in the menu bar while a panel has the keyboard. See docs/specs/05-ui.md §2.9.

import SwiftUI

/// The panel's one action button, for the menu item that repeats it.
struct PanelAction {
  let title: String
  let isEnabled: Bool
  let perform: () -> Void
}

/// Proofreading → Check or Send, ⌘↩, as Mail sends with ⌘↩.
struct PanelActionCommands: Commands {
  let panel: PanelController

  var body: some Commands {
    CommandMenu("Proofreading") {
      let action = panel.keyModel?.action
      Button(action?.title ?? "Check") { action?.perform() }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(action?.isEnabled != true)
    }
  }
}
