// Where the Proofreading panel opens and how it grows with its content. AppKit screen
// coordinates, origin at the bottom left. See docs/specs/05-ui.md §2.1.

public import CoreGraphics

public struct PanelLayout: Sendable {
  public static let width: CGFloat = 520
  /// Gap between the panel and the text field.
  static let gap: CGFloat = 8

  /// The visible frame of the screen the panel is on.
  public let screen: CGRect

  public init(screen: CGRect) {
    self.screen = screen
  }

  /// The panel grows with its content up to 70% of the screen; then only the feed scrolls.
  public var maxHeight: CGFloat { (screen.height * 0.7).rounded(.down) }

  /// Under the field if there is room, else above it, else centered on the screen.
  public func frame(height: CGFloat, near field: CGRect?) -> CGRect {
    let size = CGSize(width: Self.width, height: min(height, maxHeight))
    let centered = CGPoint(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2)
    guard let field else { return CGRect(origin: centered, size: size) }
    let x = min(max(field.minX, screen.minX), screen.maxX - size.width)
    let below = field.minY - Self.gap - size.height
    let above = field.maxY + Self.gap
    if below >= screen.minY { return CGRect(origin: CGPoint(x: x, y: below), size: size) }
    if above + size.height <= screen.maxY {
      return CGRect(origin: CGPoint(x: x, y: above), size: size)
    }
    return CGRect(origin: centered, size: size)
  }

  /// The frame for a new content height: the top edge stays, the panel stays on the screen.
  public func resized(_ frame: CGRect, to height: CGFloat) -> CGRect {
    let height = min(height, maxHeight)
    let y = min(max(frame.maxY - height, screen.minY), screen.maxY - height)
    return CGRect(x: frame.minX, y: y, width: frame.width, height: height)
  }
}
