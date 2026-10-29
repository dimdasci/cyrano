// Settings → Dictionary: search, add, edit, delete, import and export terms.
// See docs/specs/05-ui.md §5.

import AppKit
import CyranoCore
import SwiftUI
import UniformTypeIdentifiers

struct DictionaryPane: View {
  let dictionary: TermDictionary
  @State private var search = ""
  @State private var selection = Set<Term.ID>()
  @State private var sortOrder = [KeyPathComparator(\Term.added, order: .reverse)]
  @State private var editing: TermEdit?
  @State private var note: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Search \(plural(dictionary.terms.count, "term"))", text: $search)
        .textFieldStyle(.roundedBorder)
      table
      HStack {
        TermButtons(add: { editing = .add }, remove: removeSelected, canRemove: !selection.isEmpty)
        Spacer()
        if let note { Text(note).foregroundStyle(.secondary) }
        Button("Import…", action: importTerms)
        Button("Export…", action: exportTerms)
      }
      Text("Add terms from the Proofreading panel: select a word and choose Never Change.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(20)
    .sheet(item: $editing) { edit in
      TermEditor(edit: edit, dictionary: dictionary)
    }
  }

  private var table: some View {
    Table(rows, selection: $selection, sortOrder: $sortOrder) {
      TableColumn("Term", value: \.text)
      TableColumn("Added", value: \.added) { term in
        Text(term.added, format: .dateTime.year().month().day())
      }
      .width(120)
    }
    .frame(height: 280)
    .contextMenu(forSelectionType: Term.ID.self) { _ in
    } primaryAction: { ids in
      if let term = rows.first(where: { ids.contains($0.id) }) { editing = .rename(term) }
    }
    .onDeleteCommand(perform: removeSelected)
  }

  private var rows: [Term] {
    dictionary.terms
      .filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }
      .sorted(using: sortOrder)
  }

  private func removeSelected() {
    for term in rows where selection.contains(term.id) {
      dictionary.remove(term.text)
    }
    selection = []
  }

  private func importTerms() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.plainText]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    guard let list = try? String(contentsOf: url, encoding: .utf8) else {
      note = "Couldn't read the file."
      return
    }
    note = "Imported \(plural(dictionary.importTerms(from: list), "term"))."
  }

  private func exportTerms() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.plainText]
    panel.nameFieldStringValue = "Cyrano Dictionary.txt"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let saved = (try? dictionary.exported.write(to: url, atomically: true, encoding: .utf8)) != nil
    note = saved ? "Exported \(plural(dictionary.terms.count, "term"))." : "Couldn't save the file."
  }
}

/// The standard + and − under a table.
private struct TermButtons: View {
  let add: () -> Void
  let remove: () -> Void
  let canRemove: Bool

  var body: some View {
    HStack(spacing: 0) {
      Button("Add Term", systemImage: "plus", action: add)
      Button("Remove Selected Terms", systemImage: "minus", action: remove)
        .disabled(!canRemove)
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
    .controlSize(.large)
  }
}

private enum TermEdit: Identifiable {
  case add
  case rename(Term)

  var id: String {
    switch self {
    case .add: ""
    case .rename(let term): term.id
    }
  }
}

/// A new term, or a fix to one; Save is off while the text is blank or another term has it.
private struct TermEditor: View {
  let edit: TermEdit
  let dictionary: TermDictionary
  @State private var text = ""
  @State private var taken = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(isNew ? "Add Term" : "Edit Term").font(.headline)
      TextField("Term", text: $text)
        .frame(width: 280)
        .onSubmit(save)
      if taken {
        Text("This term is already in the dictionary.").font(.caption).foregroundStyle(.red)
      }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Button(isNew ? "Add" : "Save", action: save)
          .keyboardShortcut(.defaultAction)
          .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(20)
    .onAppear {
      if case .rename(let term) = edit { text = term.text }
    }
  }

  private var isNew: Bool {
    if case .add = edit { true } else { false }
  }

  private func save() {
    let saved =
      switch edit {
      case .add: dictionary.add(text)
      case .rename(let term): dictionary.rename(term.text, to: text)
      }
    if saved { dismiss() } else { taken = true }
  }
}
