// Images the user adds as context: pasted with ⌘V or dropped on the panel. See docs/specs/02 M10.

import AppKit
import UniformTypeIdentifiers

enum ContextImages {
  /// Image files on the pasteboard, else pictures. A picture that comes with text (rich text
  /// from a page) is left to the text field.
  static func fromPasteboard() -> [Data] {
    let pasteboard = NSPasteboard.general
    let files =
      pasteboard.readObjects(
        forClasses: [NSURL.self],
        options: [
          .urlReadingFileURLsOnly: true,
          .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]) as? [URL] ?? []
    if !files.isEmpty { return files.compactMap { try? Data(contentsOf: $0) }.compactMap(png) }
    guard pasteboard.string(forType: .string) == nil else { return [] }
    let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage] ?? []
    return images.compactMap { $0.tiffRepresentation }.compactMap(png)
  }

  /// Dropped images: the picture itself, else the image file it points to.
  static func load(_ providers: [NSItemProvider]) async -> [Data] {
    var images: [Data] = []
    for provider in providers {
      if let data = await data(of: provider), let image = png(data) { images.append(image) }
    }
    return images
  }

  /// Any image format as PNG, the one format the request sends.
  static func png(_ data: Data) -> Data? {
    NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:])
  }

  private static func data(of provider: NSItemProvider) async -> Data? {
    if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
      return await withCheckedContinuation { continuation in
        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) {
          data, _ in continuation.resume(returning: data)
        }
      }
    }
    let url = await withCheckedContinuation { continuation in
      _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
    }
    return url.flatMap { try? Data(contentsOf: $0) }
  }
}
