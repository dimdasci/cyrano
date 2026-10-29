// Never Change from the panel: the menu item for a term, and the status line with Undo.
// See docs/specs/05-ui.md §2.4, §2.7.

import CyranoCore

/// One line under the composer.
enum PanelStatus: Equatable {
  case note(String)
  /// A change to the dictionary that Undo reverts.
  case added(String)
  case removed(Term)

  var text: String {
    switch self {
    case .note(let text): text
    case .added(let term): "“\(term)” added to Dictionary."
    case .removed(let term): "“\(term.text)” removed from Dictionary."
    }
  }

  var canUndo: Bool {
    if case .note = self { false } else { true }
  }
}

/// A context menu item that changes the dictionary.
struct DictionaryItem {
  let title: String
  let perform: () -> Void
}

extension PanelModel {
  /// For selected text: Never Change, or Remove when the term is in the dictionary.
  func selectionItem(for term: String) -> DictionaryItem {
    if session.dictionary.contains(term) {
      return DictionaryItem(title: "Remove “\(term)” from Dictionary") {
        self.removeFromDictionary(term)
      }
    }
    return DictionaryItem(title: "Never Change “\(term)”") {
      if self.session.dictionary.add(term) { self.status = .added(term) }
    }
  }

  /// For a change: Never Change for each replaced word, which also rejects the change.
  func changeItems(for change: Change) -> [DictionaryItem] {
    change.terms.map { term in
      DictionaryItem(title: "Never Change “\(term)”") {
        if self.session.neverChange(change, keeping: term) { self.status = .added(term) }
      }
    }
  }

  func undo() {
    switch status {
    case .added(let term): session.dictionary.remove(term)
    case .removed(let term): session.dictionary.add(term.text, at: term.added)
    case .note, nil: break
    }
    status = nil
  }

  private func removeFromDictionary(_ term: String) {
    guard let removed = session.dictionary.remove(term) else { return }
    status = .removed(removed)
  }
}
