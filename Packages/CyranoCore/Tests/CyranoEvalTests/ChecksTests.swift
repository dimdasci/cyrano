import Foundation
import Testing

@testable import CyranoEval

/// Eval checks look only for clear errors (04 §5).
@Suite struct ChecksTests {
  func checks(_ json: String) throws -> Checks {
    try JSONDecoder().decode(Checks.self, from: Data(json.utf8))
  }

  @Test func requiredAndForbiddenTextIgnoreCaseAndCurlyQuotes() throws {
    let expect = try checks(
      #"{ "mustContain": ["luke schulta", "it's"], "mustNotContain": ["Will reply soon"] }"#)

    #expect(expect.failures(in: "With: Luke Schulta. It’s a thread.").isEmpty)
    #expect(
      expect.failures(in: "With: Luke.")
        == ["missing \"luke schulta\"", "missing \"it's\""])
    #expect(
      expect.failures(in: "Luke Schulta, it's: will reply soon")
        == ["has \"Will reply soon\""])
  }

  @Test func emptyMeansNoContextAtAll() throws {
    let expect = try checks(#"{ "empty": true }"#)

    #expect(expect.failures(in: " \n").isEmpty)
    #expect(expect.failures(in: "With: nobody") == ["expected no context"])
  }

  @Test func casesFileDecodesWithOptionalFields() throws {
    let json = #"[{ "id": "doc", "image": "doc.png", "text": "Draft", "expect": {} }]"#
    let cases = try JSONDecoder().decode([ContextCase].self, from: Data(json.utf8))

    #expect(cases.map(\.id) == ["doc"])
    #expect(cases[0].target == nil)
    #expect(cases[0].expect.failures(in: "anything").isEmpty)
  }
}
