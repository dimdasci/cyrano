// Who the user is writing to, what about, in which language: text and images, above the feed.
// See docs/specs/05-ui.md §2.3a.

import AppKit
import CyranoCore
import QuickLook
import SwiftUI
import TipKit

/// Context input: text, images, 📷. Before the first check it is open and focused, so the user
/// can say who they are writing to before anything is sent; the check starts by the dialog field.
struct ContextBar: View {
  let model: PanelModel
  @Bindable var session: ProofreadingSession
  @State private var expanded: Bool
  @State private var explainingCapture = false
  @State private var previewing: URL?
  /// One hint at a time: Context first, then 📷.
  @State private var tips = TipGroup(.ordered) {
    ContextTip()
    CaptureTip()
  }

  init(model: PanelModel, session: ProofreadingSession) {
    self.model = model
    self.session = session
    _expanded = State(initialValue: session.versions.isEmpty)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Button(expanded ? "▾ Context" : "▸ Context") { expanded.toggle() }
          .buttonStyle(.plain)
          .fontWeight(.semibold)
          // VoiceOver hears the state in words instead of the triangle.
          .accessibilityLabel("Context")
          .accessibilityValue(expanded ? "Expanded" : "Collapsed")
        if let status = session.contextStatus {
          ContextStatusLine(session: session, status: status)
        } else if !expanded {
          collapsedSummary
        }
        Spacer()
        if model.canCaptureWindow {
          captureButton
        }
      }
      if expanded {
        contextEditor
        imagesRow
        tip
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    // A request folds Context away; reading it does not.
    .onChange(of: session.isBusy) { _, busy in
      if busy && !session.isReadingContext { expanded = false }
    }
    .quickLookPreview($previewing)
  }

  private var contextEditor: some View {
    // Without captured text the cursor goes to Text to check instead.
    FieldText(
      text: $session.context, label: "Context",
      takesFocus: session.versions.isEmpty && !session.original.isEmpty
    )
    .frame(height: 64)
    // The field draws text edge to edge; the inset keeps it off the border.
    .padding(.horizontal, 6)
    .padding(.vertical, 6)
    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
  }

  /// Hints before the first check, while the user fills in the context.
  @ViewBuilder private var tip: some View {
    if session.versions.isEmpty {
      if let tip = tips.currentTip as? ContextTip {
        TipView(tip)
      } else if model.canCaptureWindow, let tip = tips.currentTip as? CaptureTip {
        TipView(tip)
      }
    }
  }

  @ViewBuilder private var collapsedSummary: some View {
    if let firstLine = session.context.split(whereSeparator: \.isNewline).first {
      Text(firstLine).foregroundStyle(.secondary).lineLimit(1)
        .onTapGesture { expanded = true }
    } else if session.images.isEmpty {
      Text("Add who you're writing to").foregroundStyle(.tertiary).lineLimit(1)
        .onTapGesture { expanded = true }
    }
    thumbnails(size: CGSize(width: 30, height: 22), removable: false)
  }

  /// Many images get a warning sign: orange text falls below 4.5:1 on the light window.
  private var imagesRow: some View {
    HStack(spacing: 8) {
      thumbnails(size: CGSize(width: 56, height: 38), removable: true)
      if session.hasManyImages {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
          .accessibilityHidden(true)
      }
      Text(caption)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
    }
  }

  private func thumbnails(size: CGSize, removable: Bool) -> some View {
    ForEach(Array(session.images.enumerated()), id: \.offset) { index, png in
      Thumbnail(
        png: png, size: size, name: "Image \(index + 1) of \(session.images.count)",
        open: { preview(png, number: index + 1) },
        remove: removable ? { session.images.remove(at: index) } : nil
      )
    }
  }

  /// Quick Look needs a file. Each preview gets a new folder: Quick Look caches by URL.
  private func preview(_ png: Data, number: Int) {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let url = folder.appending(path: "Context image \(number).png")
    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try png.write(to: url)
      previewing = url
    } catch {
      previewing = nil
    }
  }

  private var caption: String {
    var text = "or paste ⌘V / drop images"
    switch session.images.count {
    case 0: break
    case 1: text += " · 1 image"
    default: text += " · \(session.images.count) images"
    }
    if session.hasManyImages { text += " — checks get slower and use more of your limit" }
    return text
  }

  private var captureButton: some View {
    Button {
      CaptureTip().invalidate(reason: .actionPerformed)
      if CGPreflightScreenCaptureAccess() {
        model.captureWindow()
      } else {
        explainingCapture = true
      }
    } label: {
      Image(systemName: "camera")
    }
    .buttonStyle(.borderless)
    .help("Add a screenshot of the window you're writing in")
    .accessibilityLabel("Capture window")
    .disabled(session.isBusy)
    .popover(isPresented: $explainingCapture, arrowEdge: .bottom) {
      CaptureAccessPrompt {
        explainingCapture = false
        if CGRequestScreenCaptureAccess() {
          model.captureWindow()
        } else {
          PermissionStatus.screenRecording.openSettings()
        }
      }
    }
  }
}

/// One line before the system asks for Screen Recording the first time.
private struct CaptureAccessPrompt: View {
  let proceed: () -> Void

  var body: some View {
    VStack(alignment: .trailing, spacing: 10) {
      Text("To see the conversation you're writing in, Cyrano needs to capture this window once.")
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 260, alignment: .leading)
      Button("Continue", action: proceed)
        .keyboardShortcut(.defaultAction)
    }
    .padding(12)
  }
}

/// A thumbnail is a button that opens Quick Look, with Remove Image as its VoiceOver action; the
/// ✕ on it is a button of its own, next in the Tab order (05 §7).
private struct Thumbnail: View {
  let png: Data
  let size: CGSize
  let name: String
  let open: () -> Void
  let remove: (() -> Void)?

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Button(action: open) {
        Image(nsImage: NSImage(data: png) ?? NSImage())
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: size.width, height: size.height)
          .clipShape(RoundedRectangle(cornerRadius: 3))
          .overlay(RoundedRectangle(cornerRadius: 3).stroke(.separator))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(name)
      .accessibilityHint("Opens Quick Look")
      .accessibilityActions {
        if let remove { Button("Remove Image", action: remove) }
      }
      if let remove {
        Button(action: remove) {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.white, .black.opacity(0.6))
        }
        .buttonStyle(.plain)
        .offset(x: 5, y: -5)
        .accessibilityLabel("Remove \(name)")
      }
    }
    .padding(.top, 5)
  }
}
