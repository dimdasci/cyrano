// The floating Proofreading panel. See docs/specs/05-ui.md §2.1.

import AppKit
import CyranoCore
import Observation
import SwiftUI

/// What one panel shows and the actions it needs from the app.
@Observable
final class PanelModel {
  let session: ProofreadingSession
  let captured: CapturedText
  let app: AppModel
  /// One line under the composer: the result of Copy or of a change to the dictionary.
  var status: PanelStatus?
  /// The panel content measured the height it needs to show everything (05 §2.1).
  @ObservationIgnored var idealHeightChanged: (CGFloat) -> Void = { _ in }

  init(session: ProofreadingSession, captured: CapturedText, app: AppModel) {
    self.session = session
    self.captured = captured
    self.app = app
  }

  /// The source app goes into the title bar, which truncates it natively; the header row keeps
  /// its width for the pop-ups.
  var title: String { "Proofreading — \(captured.appName)" }

  func copy(_ text: String) {
    Clipboard.copy(text)
    status = .note("Copied.")
  }

  /// Panel settings changed: remember them for the app and check the latest version again.
  /// Before the first check there is nothing to recheck yet.
  func optionsChanged() {
    app.appDefaults.remember(session.options, for: captured.bundleID)
    guard !session.versions.isEmpty else { return }
    Task { await session.check() }
  }

  /// 📷 needs the app the text came from; pasted text has none.
  var canCaptureWindow: Bool { captured.source != nil }

  /// Adds a screenshot of the source app's front window to the context (M10).
  func captureWindow() {
    guard let app = captured.source else { return }
    Task {
      guard let png = await ScreenCapture.frontWindow(of: app) else {
        status = .note("Couldn't capture the window. Check Screen Recording in Settings.")
        return
      }
      session.images.append(png)
    }
  }

  func signInAndRetry() {
    app.signInWithChatGPT { [session] in Task { await session.tryAgain() } }
  }
}

/// The panel is as tall as its content up to 70% of the screen; then the feed scrolls (05 §2.1).
/// A closed panel is released with its session, versions and images, however it was closed.
final class PanelController: NSObject, NSWindowDelegate {
  private var panel: ProofreadingPanel?

  func show(_ model: PanelModel, near field: CGRect?) {
    close()
    let panel = ProofreadingPanel()
    panel.delegate = self
    panel.title = model.title
    let content = NSHostingView(rootView: ProofreadingView(model: model))
    // The ideal size for the first frame, read before the view is in the window. In the window
    // only this controller sizes it: AppKit and SwiftUI would resize the window inside a layout
    // pass, and a fractional height against the pixel-aligned frame makes it lay the window out
    // again and again until it throws. So the view gives no sizes, and it sits in a plain view:
    // SwiftUI resizes the window whose content view it is.
    content.sizingOptions = [.intrinsicContentSize]
    content.layoutSubtreeIfNeeded()
    let height = content.intrinsicContentSize.height
    content.sizingOptions = []
    content.autoresizingMask = [.width, .height]
    let container = NSView()
    container.addSubview(content)
    panel.contentView = container
    let layout = PanelLayout(screen: Self.screenWithMouse())
    panel.setFrame(
      layout.frame(height: panel.frameHeight(height), near: Self.appKit(field)), display: false)
    content.frame = container.bounds
    // Measured during layout, so the window frame changes on the next turn.
    model.idealHeightChanged = { [weak panel] height in
      DispatchQueue.main.async {
        guard let panel else { return }
        let frame = layout.resized(panel.frame, to: panel.frameHeight(height))
        if abs(frame.height - panel.frame.height) >= 1 { panel.setFrame(frame, display: true) }
      }
    }
    panel.orderFrontRegardless()
    panel.makeKey()
    self.panel = panel
  }

  func close() {
    panel?.close()
  }

  func windowWillClose(_ notification: Notification) {
    if notification.object as? NSWindow === panel { panel = nil }
  }

  private static func screenWithMouse() -> CGRect {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    return screen?.visibleFrame ?? .zero
  }

  /// AX gives the field with the origin at the top left of the primary screen.
  private static func appKit(_ field: CGRect?) -> CGRect? {
    guard let field, let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }
    return CGRect(
      x: field.minX, y: primaryHeight - field.maxY, width: field.width, height: field.height)
  }
}

/// Floats over the app being edited without taking activation from it. While Cyrano itself is
/// active (Settings, About, setup), the panel is an ordinary window, so the window opened or
/// clicked last is in front: a floating panel would cover them.
private final class ProofreadingPanel: NSPanel {
  private var observers: [any NSObjectProtocol] = []

  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
      backing: .buffered, defer: false)
    level = NSApp.isActive ? .normal : .floating
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    becomesKeyOnlyIfNeeded = true
    observers = [
      floats(.normal, on: NSApplication.didBecomeActiveNotification),
      floats(.floating, on: NSApplication.didResignActiveNotification),
    ]
  }

  private func floats(_ level: NSWindow.Level, on name: Notification.Name) -> any NSObjectProtocol {
    NotificationCenter.default.addObserver(forName: name, object: NSApp, queue: .main) {
      [weak self] _ in
      // Posted on the main queue.
      MainActor.assumeIsolated { self?.level = level }
    }
  }

  override func close() {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    super.close()
  }

  override var canBecomeKey: Bool { true }

  /// The window height for a content height: the content plus the title bar.
  func frameHeight(_ content: CGFloat) -> CGFloat {
    frameRect(forContentRect: CGRect(x: 0, y: 0, width: PanelLayout.width, height: content)).height
  }

  override func cancelOperation(_ sender: Any?) {
    close()
  }
}
