// What the user is replying to: text and images, above the feed. See docs/specs/05-ui.md §2.3a.

import AppKit
import CyranoCore
import SwiftUI

/// Context and the Check button. Before the first check the context is open and focused, so the
/// user can paste what they are replying to before anything is sent.
struct ContextBar: View {
  let model: PanelModel
  @Bindable var session: ProofreadingSession
  @State private var expanded: Bool
  @State private var explainingCapture = false
  @FocusState private var editing: Bool

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
        if !expanded {
          collapsedSummary
        }
        Spacer()
        if model.canCaptureWindow {
          captureButton
        }
        checkButton
      }
      if expanded {
        TextEditor(text: $session.context)
          .font(.body)
          .frame(height: 64)
          // The editor draws text edge to edge; the inset keeps it off the border.
          .scrollContentBackground(.hidden)
          .padding(.horizontal, 4)
          .padding(.vertical, 6)
          .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
          .focused($editing)
          .onAppear { editing = session.versions.isEmpty }
        imagesRow
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  @ViewBuilder private var collapsedSummary: some View {
    if let firstLine = session.context.split(whereSeparator: \.isNewline).first {
      Text(firstLine).foregroundStyle(.secondary).lineLimit(1)
        .onTapGesture { expanded = true }
    } else if session.images.isEmpty {
      Text("Add what you're replying to").foregroundStyle(.tertiary).lineLimit(1)
        .onTapGesture { expanded = true }
    }
    thumbnails(size: CGSize(width: 30, height: 22), removable: false)
  }

  private var imagesRow: some View {
    HStack(spacing: 8) {
      thumbnails(size: CGSize(width: 56, height: 38), removable: true)
      Text(caption)
        .font(.caption)
        .foregroundStyle(session.hasManyImages ? .orange : .secondary)
        .lineLimit(2)
    }
  }

  private func thumbnails(size: CGSize, removable: Bool) -> some View {
    ForEach(Array(session.images.enumerated()), id: \.offset) { index, png in
      Thumbnail(
        png: png, size: size, remove: removable ? { session.images.remove(at: index) } : nil)
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
      if CGPreflightScreenCaptureAccess() {
        model.captureWindow(into: session)
      } else {
        explainingCapture = true
      }
    } label: {
      Image(systemName: "camera")
    }
    .buttonStyle(.borderless)
    .help("Add a screenshot of the window you're replying in")
    .accessibilityLabel("Capture window")
    .disabled(session.isBusy)
    .popover(isPresented: $explainingCapture, arrowEdge: .bottom) {
      CaptureAccessPrompt {
        explainingCapture = false
        if CGRequestScreenCaptureAccess() {
          model.captureWindow(into: session)
        } else {
          PermissionStatus.screenRecording.openSettings()
        }
      }
    }
  }

  @ViewBuilder private var checkButton: some View {
    if session.versions.isEmpty {
      Button("Check") { start() }
        .buttonStyle(.borderedProminent)
        .disabled(session.isBusy)
    } else {
      Button("Recheck") { start() }
        .disabled(session.isBusy)
    }
  }

  private func start() {
    expanded = false
    Task { await session.check() }
  }
}

/// One line before the system asks for Screen Recording the first time.
private struct CaptureAccessPrompt: View {
  let proceed: () -> Void

  var body: some View {
    VStack(alignment: .trailing, spacing: 10) {
      Text("To see the conversation you're replying to, Cyrano needs to capture this window once.")
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 260, alignment: .leading)
      Button("Continue", action: proceed)
        .keyboardShortcut(.defaultAction)
    }
    .padding(12)
  }
}

private struct Thumbnail: View {
  let png: Data
  let size: CGSize
  let remove: (() -> Void)?

  var body: some View {
    Image(nsImage: NSImage(data: png) ?? NSImage())
      .resizable()
      .aspectRatio(contentMode: .fill)
      .frame(width: size.width, height: size.height)
      .clipShape(RoundedRectangle(cornerRadius: 3))
      .overlay(RoundedRectangle(cornerRadius: 3).stroke(.separator))
      .overlay(alignment: .topTrailing) {
        if let remove {
          Button(action: remove) {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.white, .black.opacity(0.6))
          }
          .buttonStyle(.plain)
          .offset(x: 5, y: -5)
          .accessibilityLabel("Remove image")
        }
      }
      .padding(.top, 5)
      .accessibilityLabel("Context image")
  }
}
