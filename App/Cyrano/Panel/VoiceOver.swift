// What Cyrano tells VoiceOver without moving its cursor. See docs/specs/05-ui.md §7.

import AppKit

enum VoiceOver {
  /// Says the text in full, interrupting what VoiceOver is reading: a new card, an answer, an
  /// error or a status. Without VoiceOver nothing happens.
  static func announce(_ text: String) {
    NSAccessibility.post(
      element: NSApp as Any, notification: .announcementRequested,
      userInfo: [
        .announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue,
      ])
  }
}
