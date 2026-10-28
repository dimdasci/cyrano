// Thin typed access to the Accessibility API of other apps.

import ApplicationServices
import CoreGraphics

extension AXUIElement {
  func string(_ attribute: String) -> String? {
    copy(attribute) as? String
  }

  func element(_ attribute: String) -> AXUIElement? {
    guard let value = copy(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else {
      return nil
    }
    // swiftlint:disable:next force_cast - the CF type id is checked above
    return (value as! AXUIElement)
  }

  func bool(_ attribute: String) -> Bool {
    (copy(attribute) as? Bool) ?? false
  }

  var children: [AXUIElement] {
    guard let value = copy("AXChildren"), CFGetTypeID(value) == CFArrayGetTypeID() else {
      return []
    }
    return (value as? [AnyObject] ?? []).compactMap { child in
      guard CFGetTypeID(child) == AXUIElementGetTypeID() else { return nil }
      // swiftlint:disable:next force_cast - the CF type id is checked above
      return (child as! AXUIElement)
    }
  }

  /// Frame in screen coordinates with the origin at the top left of the main screen.
  var frame: CGRect? {
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard let position = axValue("AXPosition"), let extent = axValue("AXSize"),
      AXValueGetValue(position, .cgPoint, &origin), AXValueGetValue(extent, .cgSize, &size)
    else { return nil }
    return CGRect(origin: origin, size: size)
  }

  @discardableResult
  func set(_ attribute: String, _ value: CFTypeRef) -> Bool {
    AXUIElementSetAttributeValue(self, attribute as CFString, value) == .success
  }

  private func axValue(_ attribute: String) -> AXValue? {
    guard let value = copy(attribute), CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    // swiftlint:disable:next force_cast - the CF type id is checked above
    return (value as! AXValue)
  }

  private func copy(_ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else {
      return nil
    }
    return value
  }
}
