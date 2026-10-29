// Screenshot of the front window: an image for Context (02 M10) and what Context is read from
// (02 C6).

import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenCapture {
  /// PNG of the app's frontmost window; nil without Screen Recording permission.
  static func frontWindow(of app: NSRunningApplication) async -> Data? {
    guard let id = frontWindowID(of: app.processIdentifier),
      let content = try? await SCShareableContent.excludingDesktopWindows(
        false, onScreenWindowsOnly: true),
      let window = content.windows.first(where: { $0.windowID == id })
    else { return nil }
    let filter = SCContentFilter(desktopIndependentWindow: window)
    let configuration = SCStreamConfiguration()
    configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
    configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
    guard
      let image = try? await SCScreenshotManager.captureImage(
        contentFilter: filter, configuration: configuration)
    else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  }

  /// The window list is ordered front to back; layer 0 skips menus and overlays.
  private static func frontWindowID(of pid: pid_t) -> CGWindowID? {
    let windows =
      CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[String: Any]] ?? []
    let window = windows.first { info in
      info[kCGWindowOwnerPID as String] as? pid_t == pid
        && info[kCGWindowLayer as String] as? Int == 0
    }
    return window?[kCGWindowNumber as String] as? CGWindowID
  }
}
