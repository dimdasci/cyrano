import Foundation
import Testing

@testable import CyranoEval

/// Eval checks look only for clear errors (04 §5).
@Suite struct ChecksTests {
  func checks(_ json: String) throws -> Checks {
    try JSONDecoder().decode(Checks.self, from: Data(json.utf8))
  }

  func lukeChecks() throws -> Checks {
    try checks(
      #"{ "mustContain": ["luke schulta", "it's"], "mustNotContain": ["Will reply soon"] }"#)
  }

  @Test func requiredTextIgnoresCaseAndCurlyQuotes() throws {
    let failures: [String] = try lukeChecks().failures(in: "With: Luke Schulta. It’s a thread.")
    #expect(failures.isEmpty)
  }

  @Test func missingRequiredTextIsAFailure() throws {
    let failures: [String] = try lukeChecks().failures(in: "With: Luke.")
    let expected: [String] = ["missing \"luke schulta\"", "missing \"it's\""]
    #expect(failures == expected)
  }

  @Test func forbiddenTextIsAFailureInAnyCase() throws {
    let failures: [String] = try lukeChecks().failures(in: "Luke Schulta, it's: will reply soon")
    let expected: [String] = ["has \"Will reply soon\""]
    #expect(failures == expected)
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
