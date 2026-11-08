// The Proofreading panel: an ordinary window of Cyrano. See docs/specs/05-ui.md §2.1.

import AppKit
import CyranoCore
import Observation
import SwiftUI
import TipKit

/// What one panel shows and the actions it needs from the app.
@Observable
final class PanelModel {
  let session: ProofreadingSession
  let captured: CapturedText
  let app: AppModel
  /// One line under the composer: the result of Copy or of a change to the dictionary. VoiceOver
  /// hears it in full, though the line may truncate it (05 §7).
  var status: PanelStatus? {
    didSet {
      if let status { VoiceOver.announce(status.text) }
    }
  }
  /// The message in the dialog field, for the action button and its menu item.
  var draft = ""
  /// The panel content measured the height it needs to show everything (05 §2.1).
  @ObservationIgnored var idealHeightChanged: (CGFloat) -> Void = { _ in }

  init(session: ProofreadingSession, captured: CapturedText, app: AppModel) {
    self.session = session
    self.captured = captured
    self.app = app
    session.announce = VoiceOver.announce
  }

  /// The source app goes into the title bar, which truncates it natively; the header row keeps
  /// its width for the pop-ups.
  var title: String { "Proofreading — \(captured.appName)" }

  func copy(_ text: String) {
    Clipboard.copy(text)
    status = .note("Copied.")
  }

  /// Check or Send, with the label and state Core decides (05 §2.7).
  var action: PanelAction {
    let message = draft
    let kind = session.action(for: message)
    return PanelAction(
      title: kind == .check ? "Check" : "Send", isEnabled: session.canPerform(message: message)
    ) { [self] in
      guard session.canPerform(message: message) else { return }
      draft = ""
      switch kind {
      case .check: ContextTip().invalidate(reason: .actionPerformed)
      case .send: DialogTip().invalidate(reason: .actionPerformed)
      }
      Task { await session.perform(message: message) }
    }
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
@Observable
final class PanelController: NSObject, NSWindowDelegate {
  @ObservationIgnored private var window: ProofreadingWindow?
  @ObservationIgnored private var model: PanelModel?
  /// The panel with the keyboard, for its action in the menu bar (05 §2.9).
  private(set) var keyModel: PanelModel?

  var isOpen: Bool { window != nil }

  /// With a panel open, the user decides first: close it for the new text, or return to it with
  /// everything in it. Without one, the new panel opens at once (05 §2.1).
  func open(_ makeModel: @escaping () -> PanelModel, near field: CGRect?) {
    guard let window else {
      show(makeModel(), near: field)
      return
    }
    AppPresence.activate()
    window.makeKeyAndOrderFront(nil)
    // A second press while the question is up asks nothing new.
    guard window.attachedSheet == nil else { return }
    let alert = NSAlert()
    alert.messageText = "Close this panel and check the new text?"
    alert.informativeText = "Its versions and conversation will be closed."
    alert.addButton(withTitle: "Check New Text")
    alert.addButton(withTitle: "Return to Panel").keyEquivalent = "\u{1b}"
    alert.beginSheetModal(for: window) { [weak self] response in
      guard response == .alertFirstButtonReturn else { return }
      self?.show(makeModel(), near: field)
    }
  }

  private func show(_ model: PanelModel, near field: CGRect?) {
    discard()
    let window = ProofreadingWindow()
    window.delegate = self
    window.title = model.title
    window.addImages = { model.session.images += $0 }
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
    window.contentView = container
    let layout = PanelLayout(screen: Self.screenWithMouse())
    window.setFrame(
      layout.frame(height: window.frameHeight(height), near: Self.appKit(field)), display: false)
    content.frame = container.bounds
    // Measured during layout, so the window frame changes on the next turn.
    model.idealHeightChanged = { [weak window] height in
      DispatchQueue.main.async {
        guard let window else { return }
        let frame = layout.resized(window.frame, to: window.frameHeight(height))
        if abs(frame.height - window.frame.height) >= 1 { window.setFrame(frame, display: true) }
      }
    }
    self.window = window
    self.model = model
    AppPresence.activate()
    window.makeKeyAndOrderFront(nil)
  }

  func windowDidBecomeKey(_ notification: Notification) {
    keyModel = model
  }

  func windowDidResignKey(_ notification: Notification) {
    keyModel = nil
  }

  /// Closed by the user: a context still being read is stopped, its call ends with the panel,
  /// and the keyboard goes back to the app the text came from, with its caret where it was.
  /// A panel closed while another app is in front leaves that app there.
  func windowWillClose(_ notification: Notification) {
    guard notification.object as? NSWindow === window else { return }
    if NSApp.isActive, let source = model?.captured.source {
      NSApp.yieldActivation(to: source)
      source.activate()
    }
    discard()
  }

  /// The panel goes away for a new one: nothing to give back yet.
  private func discard() {
    model?.session.stopReadingContext()
    window?.delegate = nil
    window?.close()
    window = nil
    model = nil
    keyModel = nil
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

/// An ordinary window of Cyrano: it activates the app, goes behind other apps' windows like any
/// window, and stays open until the user closes it with ✕, ⌘W or Esc (05 §2.1).
final class ProofreadingWindow: NSWindow {
  /// Images pasted anywhere in the panel go to Context.
  var addImages: ([Data]) -> Void = { _ in }

  init() {
    super.init(
      contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered,
      defer: false)
    isReleasedWhenClosed = false
    tabbingMode = .disallowed
    // The SwiftUI content sits in a plain view for sizing (see `show`), and without this AppKit's
    // key view loop ends at the dialog field: Tab after Send would go back to it, not to the top.
    autorecalculatesKeyViewLoop = true
  }

  /// The window height for a content height: the content plus the title bar.
  func frameHeight(_ content: CGFloat) -> CGFloat {
    frameRect(forContentRect: CGRect(x: 0, y: 0, width: PanelLayout.width, height: content)).height
  }

  override func cancelOperation(_ sender: Any?) {
    performClose(sender)
  }

  /// Edit → Paste reaches the window when no text has the keyboard, and the texts pass an image
  /// paste on to it.
  var pastesImages: Bool { ContextImages.onPasteboard }

  @objc func paste(_: Any?) {
    let images = ContextImages.fromPasteboard()
    if !images.isEmpty { addImages(images) }
  }

  override func validateMenuItem(_ item: NSMenuItem) -> Bool {
    item.action == #selector(paste(_:)) ? pastesImages : super.validateMenuItem(item)
  }
}
