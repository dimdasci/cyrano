// Drives Cyrano through Accessibility for manual checks. See SKILL.md next to it.
// Build: swiftc -O .claude/skills/verify-app/ax.swift -o .build/ax
//
//   ax windows                titles of Cyrano's windows, front first
//   ax tree [window]          role | label | value of every element (window: title substring)
//   ax wait <text> [seconds]  waits until some element's label or value contains the text
//   ax press <label>          presses the button or link with this label
//   ax select <text>          selects the text in the read-only text view that contains it
//   ax menu <text>            opens the context menu of the selection, or of the element whose
//                             label contains the text; prints the menu items
//   ax rightclick <text>      right-clicks the element whose label contains the text; prints
//                             the menu items
//   ax pick <title>           presses the open menu's item with this title
//   ax appmenu <title>        presses a menu item of the app or its menu bar icon (Settings…)
//   ax set <placeholder> <v>  puts the value into the text field with this placeholder or label
//   ax rows                   prints the rows of tables
//   ax selectrow <value>      selects the table row that has a cell with this value
//   ax doubleclick <value>    double-clicks the element with exactly this value

import AppKit
import ApplicationServices

let bundleID = "io.github.dimdasci.cyrano"

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

func application() -> AXUIElement {
  guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
  else { fail("Cyrano is not running") }
  return AXUIElementCreateApplication(app.processIdentifier)
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
  var value: AnyObject?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func string(_ element: AXUIElement, _ name: String) -> String {
  switch attribute(element, name) {
  case let text as String: text
  case let text as NSAttributedString: text.string
  case let number as NSNumber: number.stringValue
  default: ""
  }
}

func label(_ element: AXUIElement) -> String {
  for name in ["AXTitle", "AXDescription", "AXAttributedDescription"] {
    let text = string(element, name)
    if !text.isEmpty { return text }
  }
  return ""
}

func children(_ element: AXUIElement) -> [AXUIElement] {
  attribute(element, "AXChildren") as? [AXUIElement] ?? []
}

func all(_ root: AXUIElement) -> [AXUIElement] {
  [root] + children(root).flatMap(all)
}

func windows() -> [AXUIElement] {
  attribute(application(), "AXWindows") as? [AXUIElement] ?? []
}

func role(_ element: AXUIElement) -> String { string(element, "AXRole") }

func elements() -> [AXUIElement] { windows().flatMap(all) }

func tree(_ element: AXUIElement, depth: Int = 0) {
  let value = string(element, "AXValue").replacingOccurrences(of: "\n", with: "⏎")
  let help = string(element, "AXHelp")
  let parts = [role(element), label(element), String(value.prefix(160)), help]
  if role(element) != "AXGroup" || parts.dropFirst().contains(where: { !$0.isEmpty }) {
    print(String(repeating: "  ", count: depth) + parts.joined(separator: " | "))
  }
  for child in children(element) { tree(child, depth: depth + 1) }
}

func perform(_ element: AXUIElement, _ action: String) {
  let result = AXUIElementPerformAction(element, action as CFString)
  if result != .success { fail("\(action) failed: \(result.rawValue)") }
}

/// Items of the open context menu; the menu bar is left out.
func openMenuItems() -> [AXUIElement] {
  func outsideMenuBar(_ element: AXUIElement) -> [AXUIElement] {
    role(element) == "AXMenuBar" ? [] : [element] + children(element).flatMap(outsideMenuBar)
  }
  return outsideMenuBar(application()).filter { role($0) == "AXMenuItem" }
}

func frame(_ element: AXUIElement) -> CGRect {
  var origin = CGPoint.zero
  var size = CGSize.zero
  // AXPosition and AXSize are always AXValues.
  if let value = attribute(element, "AXPosition") {
    AXValueGetValue(value as! AXValue, .cgPoint, &origin)
  }
  if let value = attribute(element, "AXSize") { AXValueGetValue(value as! AXValue, .cgSize, &size) }
  return CGRect(origin: origin, size: size)
}

/// A real right click in the middle of the element, for SwiftUI context menus that ignore
/// AXShowMenu.
func rightClick(_ element: AXUIElement) {
  let rect = frame(element)
  let point = CGPoint(x: rect.midX, y: rect.midY)
  CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
    .post(tap: .cghidEventTap)
  Thread.sleep(forTimeInterval: 0.2)
  for type in [CGEventType.rightMouseDown, .rightMouseUp] {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .right)?
      .post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
  }
}

func click(_ element: AXUIElement, count: Int) {
  let rect = frame(element)
  let point = CGPoint(x: rect.midX, y: rect.midY)
  for number in 1...count {
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
      let event = CGEvent(
        mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
      event?.setIntegerValueField(.mouseEventClickState, value: Int64(number))
      event?.post(tap: .cghidEventTap)
    }
    Thread.sleep(forTimeInterval: 0.05)
  }
}

func printMenu() {
  Thread.sleep(forTimeInterval: 0.5)
  for item in openMenuItems() { print(label(item).isEmpty ? "—" : label(item)) }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard AXIsProcessTrusted() else { fail("Accessibility is not granted to this process") }

switch arguments.first {
case "windows":
  for window in windows() { print(label(window)) }
case "tree":
  let match = arguments.dropFirst().first ?? ""
  for window in windows() where match.isEmpty || label(window).contains(match) { tree(window) }
case "wait":
  let text = arguments[1]
  let deadline = Date().addingTimeInterval(Double(arguments.dropFirst(2).first ?? "30") ?? 30)
  while Date() < deadline {
    if elements().contains(where: { label($0).contains(text) || string($0, "AXValue").contains(text) }) {
      print("found \(text)")
      exit(0)
    }
    Thread.sleep(forTimeInterval: 0.5)
  }
  fail("timed out waiting for \(text)")
case "press":
  guard
    let button = elements().first(where: {
      ["AXButton", "AXLink"].contains(role($0)) && label($0) == arguments[1]
    })
  else { fail("no button \(arguments[1])") }
  perform(button, "AXPress")
  print("pressed \(arguments[1])")
case "select":
  let text = arguments[1]
  guard
    let view = elements().first(where: {
      role($0) == "AXTextArea" && string($0, "AXValue").contains(text)
    })
  else { fail("no text view with \(text)") }
  let value = string(view, "AXValue") as NSString
  var range = CFRange(location: value.range(of: text).location, length: (text as NSString).length)
  guard let axRange = AXValueCreate(.cfRange, &range) else { fail("bad range") }
  AXUIElementSetAttributeValue(view, "AXSelectedTextRange" as CFString, axRange)
  print("selected \(string(view, "AXSelectedText"))")
case "menu":
  let text = arguments[1]
  let target =
    elements().first(where: { role($0) == "AXTextArea" && string($0, "AXSelectedText") == text })
    ?? elements().first(where: { label($0).contains(text) })
  guard let target else { fail("nothing to open a menu on for \(text)") }
  perform(target, "AXShowMenu")
  printMenu()
case "rightclick":
  guard
    let target = elements().first(where: {
      label($0).contains(arguments[1]) || string($0, "AXValue").contains(arguments[1])
    })
  else {
    fail("nothing labeled \(arguments[1])")
  }
  rightClick(target)
  printMenu()
case "pick":
  guard let item = openMenuItems().first(where: { label($0) == arguments[1] }) else {
    fail("no menu item \(arguments[1])")
  }
  perform(item, "AXPress")
  print("picked \(arguments[1])")
case "appmenu":
  guard let item = all(application()).first(where: { role($0) == "AXMenuItem" && label($0) == arguments[1] })
  else { fail("no app menu item \(arguments[1])") }
  perform(item, "AXPress")
  print("chose \(arguments[1])")
case "set":
  guard
    let field = elements().first(where: {
      ["AXTextField", "AXTextArea"].contains(role($0))
        && (string($0, "AXPlaceholderValue") + label($0)).contains(arguments[1])
    })
  else { fail("no field \(arguments[1])") }
  AXUIElementSetAttributeValue(field, "AXFocused" as CFString, kCFBooleanTrue)
  AXUIElementSetAttributeValue(field, "AXValue" as CFString, arguments[2] as CFString)
  print("set \(arguments[1]) to \(string(field, "AXValue"))")
case "rows":
  for row in elements() where role(row) == "AXRow" {
    let cells = all(row).filter { role($0) == "AXStaticText" || role($0) == "AXTextField" }
    print(cells.map { string($0, "AXValue") }.joined(separator: " | "))
  }
case "selectrow":
  guard
    let row = elements().first(where: {
      role($0) == "AXRow" && all($0).contains { string($0, "AXValue") == arguments[1] }
    })
  else { fail("no row \(arguments[1])") }
  AXUIElementSetAttributeValue(row, "AXSelected" as CFString, kCFBooleanTrue)
  print("selected row \(arguments[1])")
case "doubleclick":
  guard let target = elements().first(where: { string($0, "AXValue") == arguments[1] }) else {
    fail("nothing with value \(arguments[1])")
  }
  click(target, count: 2)
  print("double-clicked \(arguments[1])")
default:
  fail("usage: ax windows|tree|wait|press|select|menu|rightclick|pick|appmenu|set|rows|selectrow|doubleclick …")
}
