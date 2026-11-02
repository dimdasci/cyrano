import CoreGraphics
import Testing

@testable import CyranoCore

/// Where the panel opens and how it grows (05 §2.1). AppKit coordinates: origin bottom left.
@Suite struct PanelLayoutTests {
  /// Visible frame of a 1440×900 screen; 70% of its height is 630.
  let layout = PanelLayout(screen: CGRect(x: 0, y: 0, width: 1440, height: 900))

  @Test func underTheFieldWhenThereIsRoom() {
    let field = CGRect(x: 100, y: 600, width: 300, height: 40)
    #expect(
      layout.frame(height: 300, near: field) == CGRect(x: 100, y: 292, width: 520, height: 300))
  }

  @Test func aboveTheFieldNearTheBottomAndInsideTheScreen() {
    let field = CGRect(x: 1300, y: 100, width: 100, height: 40)
    #expect(
      layout.frame(height: 300, near: field) == CGRect(x: 920, y: 148, width: 520, height: 300))
  }

  @Test func centeredWithoutAField() {
    #expect(layout.frame(height: 300, near: nil) == CGRect(x: 460, y: 300, width: 520, height: 300))
  }

  @Test func heightStopsAt70PercentOfTheScreen() {
    #expect(layout.frame(height: 2000, near: nil).height == 630)
  }

  @Test func growingKeepsTheTopEdgeAndStaysOnTheScreen() {
    let opened = CGRect(x: 100, y: 292, width: 520, height: 300)
    #expect(layout.resized(opened, to: 500) == CGRect(x: 100, y: 92, width: 520, height: 500))
    #expect(layout.resized(opened, to: 900) == CGRect(x: 100, y: 0, width: 520, height: 630))
  }
}
