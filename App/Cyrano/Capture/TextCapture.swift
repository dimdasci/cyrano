// Reading the text to check. See docs/specs/02 C1, C2.

import AppKit
import ApplicationServices
import OSLog

/// Steps of capture, without any text (docs/specs/02 S3).
private let log = Logger(subsystem: "io.github.dimdasci.cyrano", category: "capture")

/// The text to check and where it came from. The result goes back only through Copy.
struct CapturedText {
  let text: String
  let appName: String
  let bundleID: String?
  /// Field frame for placing the panel, top-left screen coordinates.
  let frame: CGRect?

  init(text: String, appName: String, bundleID: String? = nil, frame: CGRect? = nil) {
    self.text = text
    self.appName = appName
    self.bundleID = bundleID
    self.frame = frame
  }

  init(text: String, app: NSRunningApplication, frame: CGRect? = nil) {
    self.init(
      text: text, appName: app.localizedName ?? "App", bundleID: app.bundleIdentifier, frame: frame)
  }
}

enum TextCapture {
  /// The app the user is writing in; nil when Cyrano itself is in front.
  static var frontApp: NSRunningApplication? {
    guard let app = NSWorkspace.shared.frontmostApplication,
      app.processIdentifier != ProcessInfo.processInfo.processIdentifier
    else { return nil }
    return app
  }

  /// The selection or the whole focused field: through Accessibility, else with ⌘C, else with
  /// ⌘A ⌘C. A screenshot is the caller's last resort, since reading it needs the model.
  static func capture(from app: NSRunningApplication) async -> CapturedText? {
    log.notice(
      "capture: \(app.bundleIdentifier ?? "?", privacy: .public) trusted=\(AXIsProcessTrusted())")
    if AXIsProcessTrusted(), let captured = await fromAccessibility(app) { return captured }
    if let captured = await fromKeyboard(app, wholeField: false) { return captured }
    Clipboard.selectAll()
    return await fromKeyboard(app, wholeField: true)
  }

  /// Text the model read from a screenshot of the app's window.
  static func fromScreen(_ text: String, app: NSRunningApplication) -> CapturedText {
    CapturedText(text: text, app: app)
  }

  static func fromClipboard() -> CapturedText? {
    guard let text = Clipboard.string, hasText(text) else { return nil }
    return manual(text)
  }

  static func manual(_ text: String) -> CapturedText {
    CapturedText(text: text, appName: "Manual")
  }

  private static func fromKeyboard(_ app: NSRunningApplication, wholeField: Bool) async
    -> CapturedText?
  {
    guard let text = await Clipboard.copySelection(), hasText(text) else {
      log.notice("capture: ⌘C copied nothing, wholeField=\(wholeField)")
      return nil
    }
    log.notice("capture: ⌘C copied \(text.count) characters, wholeField=\(wholeField)")
    return CapturedText(text: text, app: app)
  }

  private static func fromAccessibility(_ app: NSRunningApplication) async -> CapturedText? {
    guard let field = await focusedTextField(app) else {
      log.notice("capture: no focused text field through Accessibility")
      return nil
    }
    let selected = field.string("AXSelectedText") ?? ""
    let isSelection = hasText(selected)
    let text = isSelection ? selected : field.string("AXValue") ?? ""
    log.notice(
      "capture: AX role=\(field.string("AXRole") ?? "?", privacy: .public) selection=\(isSelection) characters=\(text.count)"
    )
    guard hasText(text) else { return nil }
    return CapturedText(text: text, app: app, frame: field.frame)
  }

  /// The focused element with text. Chrome builds the accessibility tree of web pages only after
  /// AXEnhancedUserInterface, Electron after AXManualAccessibility; both build it asynchronously.
  private static func focusedTextField(_ app: NSRunningApplication) async -> AXUIElement? {
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    if let field = textField(in: appElement) { return field }
    appElement.set("AXManualAccessibility", kCFBooleanTrue)
    appElement.set("AXEnhancedUserInterface", kCFBooleanTrue)
    for _ in 0..<8 {
      try? await Task.sleep(for: .milliseconds(60))
      if let field = textField(in: appElement) { return field }
    }
    guard
      let root = appElement.element("AXFocusedUIElement") ?? appElement.element("AXFocusedWindow")
    else { return nil }
    return focusedDescendant(of: root)
  }

  /// Chrome may keep reporting the page as focused; the field with the caret is then somewhere
  /// inside it, marked AXFocused. Breadth-first, bounded so a huge page cannot hang the hotkey.
  private static func focusedDescendant(of root: AXUIElement) -> AXUIElement? {
    var queue = [root]
    var index = 0
    while index < queue.count, index < 5000 {
      let element = queue[index]
      index += 1
      if element.bool("AXFocused"), hasText(element.string("AXValue") ?? "") { return element }
      queue += element.children
    }
    log.notice("capture: no focused descendant among \(index) elements")
    return nil
  }

  /// The focused element if it holds text. Chrome may report the whole page (AXWebArea, empty
  /// value) as focused until its web accessibility is on; that does not count.
  private static func textField(in appElement: AXUIElement) -> AXUIElement? {
    guard let field = appElement.element("AXFocusedUIElement"),
      hasText(field.string("AXSelectedText") ?? "") || hasText(field.string("AXValue") ?? "")
    else { return nil }
    return field
  }

  private static func hasText(_ text: String) -> Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
