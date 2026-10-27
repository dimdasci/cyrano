import Testing
@testable import CyranoCore

@Test func versionIsSet() {
  #expect(!CyranoCore.version.isEmpty)
}
