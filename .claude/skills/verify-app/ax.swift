// Drives Cyrano through Accessibility for manual checks. See SKILL.md next to it.
// Build: swiftc -O .claude/skills/verify-app/ax.swift -o .build/ax
//
//   ax windows                titles of Cyrano's windows, front first
//   ax close [window]         closes Cyrano's windows (window: title substring)
//   ax tree [window]          role | label | value of every element (window: title substring)
//   ax focused                role | label | value of the element with keyboard focus
//   ax wait <text> [seconds]  waits until some element's label or value contains the text
//   ax press <label>          presses the button or link with this label
//   ax select <text>          selects the text in the read-only text view that contains it
//   ax menu <text>            opens the context menu of the selection, or of the element whose
//                             label contains the text; prints the menu items
//   ax rightclick <text>      right-clicks the element whose label contains the text; prints
//                             the menu items
//   ax pick <title>           presses the open menu's item with this title
//   ax dismiss                closes the open context menu without choosing an item
//   ax appmenu <title>        presses a menu item of the app or its menu bar icon (Settings…)
//   ax set <placeholder> <v>  puts the value into the text field with this placeholder or label,
//                             or into the Nth field from the top for @N
//   ax rows                   prints the rows of tables
//   ax selectrow <value>      selects the table or list row that has a cell with this text, or
//                             with this text followed by ", " and a state (Casual, Modified)
//   ax doubleclick <value>    double-clicks the element with exactly this value
//   ax key <key> [mods…]      presses a letter, return, tab, space, up or down in the front app
//                             like a keyboard (mods: command,
//                             option, shift, control); check the front app first
//   ax announcements [sec]    prints what Cyrano asks VoiceOver to announce during the next
//                             seconds (30 by default); VoiceOver itself may stay off

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

/// The element and everything under it, top down, with how deep each one is. Walks without
/// recursion and visits each element once: SwiftUI trees can be deep and can point back at an
/// ancestor, and recursion overflowed the stack. `skip` leaves out an element and what is under it.
func walk(_ root: AXUIElement, skip: (AXUIElement) -> Bool = { _ in false }) -> [(
  element: AXUIElement, depth: Int
)] {
  var found: [(element: AXUIElement, depth: Int)] = []
  var seen = Set<AXElement>()
  var pending = [(root, 0)]
  while let (element, depth) = pending.popLast() {
    guard depth < 200, !skip(element), seen.insert(AXElement(element)).inserted else { continue }
    found.append((element, depth))
    pending += children(element).reversed().map { ($0, depth + 1) }
  }
  return found
}

func all(_ root: AXUIElement) -> [AXUIElement] { walk(root).map(\.element) }

/// The texts of a table or list cell: its value and its label, which a view may set instead of
/// the value (a SwiftUI List row: label "Casual, Modified", no value).
func cellTexts(_ element: AXUIElement) -> [String] {
  [label(element), string(element, "AXValue")].filter { !$0.isEmpty }
}

/// AXUIElement compared by identity, for the visited set.
struct AXElement: Hashable {
  let element: AXUIElement
  init(_ element: AXUIElement) { self.element = element }
  static func == (a: Self, b: Self) -> Bool { CFEqual(a.element, b.element) }
  func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

func windows() -> [AXUIElement] {
  attribute(application(), "AXWindows") as? [AXUIElement] ?? []
}

func role(_ element: AXUIElement) -> String { string(element, "AXRole") }

func elements() -> [AXUIElement] { windows().flatMap { all($0) } }

func tree(_ window: AXUIElement) {
  for (element, depth) in walk(window) {
    let value = string(element, "AXValue").replacingOccurrences(of: "\n", with: "⏎")
    let help = string(element, "AXHelp")
    let parts = [role(element), label(element), String(value.prefix(160)), help]
    if role(element) != "AXGroup" || parts.dropFirst().contains(where: { !$0.isEmpty }) {
      let indent = String(repeating: "  ", count: depth)
      print(indent + parts.joined(separator: " | "))
    }
  }
}

func perform(_ element: AXUIElement, _ action: String) {
  let result = AXUIElementPerformAction(element, action as CFString)
  if result != .success { fail("\(action) failed: \(result.rawValue)") }
}

/// Items of the open context menu; the menu bar is left out.
func openMenuItems() -> [AXUIElement] {
  walk(application(), skip: { role($0) == "AXMenuBar" }).map(\.element).filter {
    role($0) == "AXMenuItem"
  }
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

/// Presses a letter key, or return, tab, space, up or down, with modifiers at the HID tap, like a real keyboard. System Events
/// keystrokes reach the front app but don't always trigger global hot keys such as ⌥⌘G.
func pressKey(_ letter: String, _ modifiers: [String]) {
  let codes: [String: CGKeyCode] = [
    "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11,
    "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
    "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
    "return": 36, "tab": 48, "space": 49, "up": 126, "down": 125,
  ]
  let flags: [String: CGEventFlags] = [
    "command": .maskCommand, "option": .maskAlternate, "shift": .maskShift,
    "control": .maskControl,
  ]
  guard let code = codes[letter.lowercased()] else { fail("no key \(letter)") }
  let source = CGEventSource(stateID: .hidSystemState)
  for isDown in [true, false] {
    let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: isDown)
    event?.flags = CGEventFlags(modifiers.map { flags[$0] ?? [] })
    event?.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.05)
  }
}

func printMenu() {
  Thread.sleep(forTimeInterval: 0.5)
  for item in openMenuItems() {
    // A checked item, such as Check Spelling While Typing, is printed with ✓.
    let mark = string(item, "AXMenuItemMarkChar").isEmpty ? "" : "✓ "
    print(label(item).isEmpty ? "—" : mark + label(item))
  }
}

/// Announcements arrive as AXAnnouncementRequested on the app element, with the text under
/// AXAnnouncementKey in the notification's info.
func listenToAnnouncements(for seconds: Double) {
  let app = application()
  var pid: pid_t = 0
  AXUIElementGetPid(app, &pid)
  var observer: AXObserver?
  let callback: AXObserverCallbackWithInfo = { _, _, _, info, _ in
    let value = (info as NSDictionary)[kAXAnnouncementKey as String]
    let text = (value as? NSAttributedString)?.string ?? (value as? String) ?? "\(info)"
    print("announced: \(text)")
    fflush(stdout)
  }
  guard AXObserverCreateWithInfoCallback(pid, callback, &observer) == .success, let observer
  else { fail("can't observe Cyrano") }
  AXObserverAddNotification(observer, app, kAXAnnouncementRequestedNotification as CFString, nil)
  CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
  CFRunLoopRunInMode(.defaultMode, seconds, false)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard AXIsProcessTrusted() else { fail("Accessibility is not granted to this process") }

switch arguments.first {
case "windows":
  for window in windows() { print(label(window)) }
case "close":
  let match = arguments.dropFirst().first ?? ""
  for window in windows() where match.isEmpty || label(window).contains(match) {
    guard let button = attribute(window, "AXCloseButton") else { continue }
    print("closing \(label(window))")
    // AXCloseButton is always an AXUIElement.
    perform(button as! AXUIElement, "AXPress")
  }
case "tree":
  let match = arguments.dropFirst().first ?? ""
  for window in windows() where match.isEmpty || label(window).contains(match) { tree(window) }
case "focused":
  guard let focused = attribute(application(), "AXFocusedUIElement") else { fail("no focus") }
  // AXFocusedUIElement is always an AXUIElement.
  let element = focused as! AXUIElement
  print([role(element), label(element), String(string(element, "AXValue").prefix(80))]
    .joined(separator: " | "))
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
case "dismiss":
  // Close a menu before pressing anything: if a press removes the menu's view, the menu never
  // ends tracking and KeyboardShortcuts keeps the global hot key paused.
  let menus = walk(application(), skip: { role($0) == "AXMenuBar" }).map(\.element).filter {
    role($0) == "AXMenu"
  }
  guard let menu = menus.first else { fail("no open menu") }
  perform(menu, "AXCancel")
  print("dismissed the menu")
case "appmenu":
  guard let item = all(application()).first(where: { role($0) == "AXMenuItem" && label($0) == arguments[1] })
  else { fail("no app menu item \(arguments[1])") }
  perform(item, "AXPress")
  print("chose \(arguments[1])")
case "set":
  // "@2" is the second field from the top: SwiftUI TextEditor has no label or placeholder.
  let fields = elements().filter { ["AXTextField", "AXTextArea"].contains(role($0)) }
  let field =
    arguments[1].hasPrefix("@")
    ? Int(arguments[1].dropFirst()).flatMap { fields.indices.contains($0 - 1) ? fields[$0 - 1] : nil }
    : fields.first {
      (string($0, "AXPlaceholderValue") + label($0)).contains(arguments[1])
    }
  guard let field else { fail("no field \(arguments[1])") }
  AXUIElementSetAttributeValue(field, "AXFocused" as CFString, kCFBooleanTrue)
  AXUIElementSetAttributeValue(field, "AXValue" as CFString, arguments[2] as CFString)
  print("set \(arguments[1]) to \(string(field, "AXValue"))")
case "rows":
  for row in elements() where role(row) == "AXRow" {
    let cells = all(row).filter { role($0) == "AXStaticText" || role($0) == "AXTextField" }
    print(cells.map { cellTexts($0).joined(separator: ", ") }.joined(separator: " | "))
  }
case "selectrow":
  guard
    let row = elements().first(where: {
      role($0) == "AXRow" && all($0).contains {
        cellTexts($0).contains { $0 == arguments[1] || $0.hasPrefix(arguments[1] + ", ") }
      }
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
case "key":
  pressKey(arguments[1], Array(arguments.dropFirst(2)))
  print("pressed \(arguments.dropFirst().joined(separator: " "))")
case "announcements":
  listenToAnnouncements(for: Double(arguments.dropFirst().first ?? "30") ?? 30)
default:
  fail("usage: ax windows|close|tree|focused|wait|press|select|menu|rightclick|pick|dismiss|appmenu|set|rows|selectrow|doubleclick|key|announcements …")
}
