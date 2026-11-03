// Settings → Style: custom instructions and what the panel remembers per app.
// See docs/specs/05-ui.md §5.

import AppKit
import CyranoCore
import SwiftUI
import UniformTypeIdentifiers

struct StylePane: View {
  @Bindable var app: AppModel

  var body: some View {
    Form {
      Section("Custom instructions") {
        TextEditor(text: $app.customInstructions)
          .font(.body)
          .frame(height: 96)
        Text("Added to every check, one rule per line. Changes apply to the next check.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Per-app defaults") {
        PerAppDefaults(apps: app.appDefaults)
      }
    }
    .formStyle(.grouped)
  }
}

/// App · Context · Tone · Level, filled from the panel header. Removing a row
/// resets the app to the defaults.
private struct PerAppDefaults: View {
  let apps: AppDefaults
  @State private var selection = Set<AppDefaults.Entry.ID>()

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Table(rows, selection: $selection) {
        TableColumn("App") { row in
          Label {
            Text(row.app.name)
          } icon: {
            Image(nsImage: row.app.icon).resizable().frame(width: 16, height: 16)
          }
        }
        // The other columns fit their longest values ("Professional", "Errors Only").
        TableColumn("Context") { Text($0.entry.options.textType.title) }
          .width(64)
        TableColumn("Tone") { Text($0.entry.options.tone.title) }
          .width(86)
        TableColumn("Level") { Text($0.entry.options.level.title) }
          .width(80)
      }
      .frame(height: 150)
      .onDeleteCommand(perform: resetSelected)
      Button("Reset Selected Apps", systemImage: "minus", action: resetSelected)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .controlSize(.large)
        .disabled(selection.isEmpty)
      Text(
        "Filled from the Proofreading panel. Removing an app resets it to "
          + "Message · Neutral · Fluency."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private struct Row: Identifiable {
    let entry: AppDefaults.Entry
    let app: InstalledApp

    var id: String { entry.id }
  }

  private var rows: [Row] {
    apps.entries
      .map { Row(entry: $0, app: InstalledApp($0.bundleID)) }
      .sorted { $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending }
  }

  private func resetSelected() {
    for entry in apps.entries where selection.contains(entry.id) {
      apps.reset(entry.bundleID)
    }
    selection = []
  }
}

/// Name and icon of an app by bundle id; text typed into the panel is «Manual».
private struct InstalledApp {
  let name: String
  let icon: NSImage

  init(_ bundleID: String?) {
    guard let bundleID else {
      name = "Manual"
      icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) ?? NSImage()
      return
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
      name = bundleID
      icon = NSWorkspace.shared.icon(for: .application)
      return
    }
    name = FileManager.default.displayName(atPath: url.path).replacing(/\.app$/, with: "")
    icon = NSWorkspace.shared.icon(forFile: url.path)
  }
}
