// Draws a synthetic window: an HTML template filled with the case's data, at Retina scale like
// the screenshots Cyrano takes. See evals/context/README.md.

import AppKit
import WebKit

@MainActor
struct WindowRenderer {
  /// Where the templates and the data files are.
  let folder: URL

  func png(_ page: Page, draft: String) async throws -> Data {
    let view = WKWebView(frame: CGRect(origin: .zero, size: page.size))
    let loading = PageLoading()
    view.navigationDelegate = loading
    view.loadFileURL(folder.appending(path: page.template), allowingReadAccessTo: folder)
    await loading.finished()
    let data = try String(contentsOf: folder.appending(path: page.data), encoding: .utf8)
    let text = String(decoding: try JSONEncoder().encode(draft), as: UTF8.self)
    _ = try await view.evaluateJavaScript("render(\(data), \(text)); 0")
    // Lets layout and the scroll position settle.
    try await Task.sleep(for: .milliseconds(200))
    let image = try await view.takeSnapshot(configuration: WKSnapshotConfiguration())
    return try Self.retinaPNG(image, size: page.size)
  }

  private static func retinaPNG(_ image: NSImage, size: CGSize) throws -> Data {
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { throw RenderError.noBitmap }
    // In points before the context is made, so the image fills all the pixels.
    bitmap.size = size
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
      throw RenderError.noBitmap
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    image.draw(in: CGRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
      throw RenderError.noBitmap
    }
    return png
  }
}

enum RenderError: Error {
  case noBitmap
}

@MainActor
private final class PageLoading: NSObject, WKNavigationDelegate {
  private var waiting: CheckedContinuation<Void, Never>?
  private var done = false

  func finished() async {
    guard !done else { return }
    await withCheckedContinuation { waiting = $0 }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
    done = true
    waiting?.resume()
    waiting = nil
  }
}

extension ContextCase {
  /// The window as the model sees it; `folder` holds the cases file.
  @MainActor func screenshot(in folder: URL) async throws -> Data {
    switch window {
    case .screenshot(let path): try Data(contentsOf: folder.appending(path: path))
    case .page(let page): try await WindowRenderer(folder: folder).png(page, draft: text)
    }
  }
}
