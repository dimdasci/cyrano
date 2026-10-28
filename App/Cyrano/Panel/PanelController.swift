// The floating Proofreading panel. See docs/specs/05-ui.md §2.1.

import AppKit
import CyranoCore
import Observation
import SwiftUI

/// What one panel shows and the actions it needs from the app.
@Observable
final class PanelModel {
  enum Content {
    case nothingToCheck
    case readingScreen
    case session(ProofreadingSession, CapturedText)
  }

  let content: Content
  let app: AppModel
  /// One line under the composer: the result of Copy.
  var status: String?

  init(content: Content, app: AppModel) {
    self.content = content
    self.app = app
  }

  /// The source app goes into the title bar, which truncates it natively; the header row keeps
  /// its width for the pop-ups.
  var title: String {
    guard case .session(_, let captured) = content else { return "Proofreading" }
    return "Proofreading — \(captured.appName)"
  }

  func copy(_ text: String) {
    Clipboard.copy(text)
    status = "Copied."
  }

  /// Panel settings changed: remember them for the app and check the latest version again.
  func optionsChanged(_ session: ProofreadingSession, for captured: CapturedText) {
    OptionsMemory.remember(session.options, for: captured.bundleID)
    Task { await session.check() }
  }

  func signInAndRetry(_ session: ProofreadingSession) {
    app.signInWithChatGPT { Task { await session.tryAgain() } }
  }
}

final class PanelController {
  private var panel: ProofreadingPanel?

  func show(_ model: PanelModel, near field: CGRect?) {
    close()
    let panel = ProofreadingPanel()
    panel.title = model.title
    panel.contentViewController = NSHostingController(rootView: ProofreadingView(model: model))
    panel.setContentSize(CGSize(width: 520, height: 560))
    panel.setFrameOrigin(origin(for: panel.frame.size, near: field))
    panel.orderFrontRegardless()
    panel.makeKey()
    self.panel = panel
  }

  func close() {
    panel?.close()
    panel = nil
  }

  /// Under the field if there is room, else above it, else centered on the screen with the mouse.
  private func origin(for size: CGSize, near field: CGRect?) -> CGPoint {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    let visible = screen?.visibleFrame ?? .zero
    let centered = CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
    guard let field, let primaryHeight = NSScreen.screens.first?.frame.height else {
      return centered
    }
    let fieldTop = primaryHeight - field.minY
    let fieldBottom = fieldTop - field.height
    let x = min(max(field.minX, visible.minX), visible.maxX - size.width)
    if fieldBottom - 8 - size.height >= visible.minY {
      return CGPoint(x: x, y: fieldBottom - 8 - size.height)
    }
    if fieldTop + 8 + size.height <= visible.maxY {
      return CGPoint(x: x, y: fieldTop + 8)
    }
    return centered
  }
}

/// Floats over the app being edited without taking activation from it.
private final class ProofreadingPanel: NSPanel {
  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
      backing: .buffered, defer: false)
    isFloatingPanel = true
    level = .floating
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    becomesKeyOnlyIfNeeded = true
  }

  override var canBecomeKey: Bool { true }

  override func cancelOperation(_ sender: Any?) {
    close()
  }
}
