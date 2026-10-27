import Testing
@testable import GrammarCore

@Test func versionIsSet() {
  #expect(!GrammarCore.version.isEmpty)
}
