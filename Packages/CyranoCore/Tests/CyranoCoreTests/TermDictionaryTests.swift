import Foundation
import Testing

@testable import CyranoCore

/// A dictionary file in a new temporary folder that does not exist yet.
func temporaryDictionaryFile() -> URL {
  FileManager.default.temporaryDirectory
    .appending(path: UUID().uuidString)
    .appending(path: "dictionary.json")
}

@MainActor func dictionary(_ terms: [String] = []) -> TermDictionary {
  let dictionary = TermDictionary(file: temporaryDictionaryFile())
  for term in terms { dictionary.add(term) }
  return dictionary
}

/// The «Never change» list in dictionary.json (02 M11).
@MainActor @Suite struct TermDictionaryTests {
  let added = Date(timeIntervalSince1970: 1_800_000_000)

  @Test func termsAreReadBack() {
    let file = temporaryDictionaryFile()
    TermDictionary(file: file).add("Bitbucket", at: added)
    let expected = Term(text: "Bitbucket", added: added)
    #expect(TermDictionary(file: file).terms == [expected])
  }

  @Test func theFileHoldsTermAndAddedDate() throws {
    let file = temporaryDictionaryFile()
    TermDictionary(file: file).add("Bitbucket", at: added)
    let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
    let entries = try #require(json as? [[String: String]])
    #expect(entries == [["term": "Bitbucket", "added": "2027-01-15T08:00:00Z"]])
  }

  @Test func anUnreadableFileIsKeptAside() throws {
    let file = temporaryDictionaryFile()
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("Bitbucket".utf8).write(to: file)

    let dictionary = TermDictionary(file: file)
    #expect(dictionary.terms.isEmpty)
    let backup = file.appendingPathExtension("bak")
    #expect(try String(contentsOf: backup, encoding: .utf8) == "Bitbucket")
  }

  @Test func addingSkipsBlanksAndTermsInAnyCase() {
    let dictionary = dictionary(["Bitbucket"])
    #expect(!dictionary.add("bitbucket"))
    #expect(!dictionary.add("  "))
    #expect(dictionary.add(" k8s "))
    #expect(dictionary.terms.map(\.text) == ["Bitbucket", "k8s"])
    #expect(dictionary.contains("BITBUCKET"))
  }

  @Test func removingAndRenamingAreSaved() {
    let file = temporaryDictionaryFile()
    let dictionary = TermDictionary(file: file)
    for term in ["Bitbucket", "k8s", "Jira"] { dictionary.add(term) }
    #expect(dictionary.remove("BitBucket")?.text == "Bitbucket")
    #expect(!dictionary.rename("k8s", to: "jira"))
    #expect(dictionary.rename("k8s", to: "K8s"))
    #expect(TermDictionary(file: file).terms.map(\.text) == ["K8s", "Jira"])
  }

  @Test func importReadsOneTermPerLine() {
    let dictionary = dictionary(["Bitbucket"])
    let count = dictionary.importTerms(from: "k8s\n\n  Jira \nbitbucket\r\nk8s\n")
    #expect(count == 2)
    #expect(dictionary.exported == "Bitbucket\nk8s\nJira\n")
  }

  /// Selection and the term it gives; "" means none.
  nonisolated static let selections: [(String, String)] = [
    (" Bitbucket. ", "Bitbucket"), ("“k8s”,", "k8s"), ("pull request", "pull request"),
    ("C++", "C++"), ("two\nlines", ""), (" , ", ""),
  ]

  @Test(arguments: selections)
  func aSelectionBecomesATerm(selection: String, term: String) {
    #expect(TermDictionary.term(fromSelection: selection) ?? "" == term)
  }
}

/// Only terms that occur in the text go to the model: any case, whole words (02 M11).
@MainActor @Suite struct TermMatchingTests {
  @Test func termsAreFoundInAnyCase() {
    let dictionary = dictionary(["Bitbucket", "Jira"])
    #expect(dictionary.found(in: "Pushed to bitbucket.") == ["Bitbucket"])
  }

  @Test func termsAreFoundOnlyAsWholeWords() {
    let dictionary = dictionary(["Go", "k8s", "Bitbucket"])
    #expect(dictionary.found(in: "Google it") == [])
    #expect(dictionary.found(in: "a k8s-cluster") == ["k8s"])
    #expect(dictionary.found(in: "Bitbucket's PRs, Go!") == ["Bitbucket", "Go"])
  }

  @Test func phrasesAndSymbolsAreFound() {
    let dictionary = dictionary(["pull request", "C++"])
    #expect(dictionary.found(in: "My C++ Pull Request") == ["C++", "pull request"])
    #expect(dictionary.found(in: "pull requests") == [])
  }

  @Test func termsComeInTheOrderOfTheText() {
    let dictionary = dictionary(["Jira", "Bitbucket", "Slack"])
    #expect(dictionary.found(in: "Slack, then Jira and Slack again") == ["Slack", "Jira"])
  }
}

/// A term the text spells a letter or two off is a spelling hint for Fix (04 §4.2).
@MainActor @Suite struct MisspelledTermTests {
  @Test func aNameOneLetterOffIsFound() {
    let dictionary = dictionary(["Priya", "Jira"])
    #expect(dictionary.misspelled(in: "Met Laura and Pria today.") == ["Priya"])
  }

  @Test func swappedLettersCountAsOneEdit() {
    #expect(dictionary(["Aoife"]).misspelled(in: "Thanks, Aiofe!") == ["Aoife"])
  }

  @Test func longTermsAllowTwoEdits() {
    let dictionary = dictionary(["Kestrela", "Katarzyna"])
    #expect(dictionary.misspelled(in: "Katarzinna deployed Kestrrella.") == ["Katarzyna"])
  }

  @Test func phrasesAreComparedWordForWord() {
    #expect(dictionary(["dev env"]).misspelled(in: "It works on dev emv now.") == ["dev env"])
  }

  /// "quick" is a word of its own; "k8s" is too short to tell a typo from another term.
  @Test func caseOnlyAndShortTermsAreNotHints() {
    let dictionary = dictionary(["Quick", "k8s", "Priya"])
    #expect(dictionary.misspelled(in: "A quick k9s check with Priya.") == [])
  }

  @Test func hintsComeInTheOrderOfTheText() {
    let dictionary = dictionary(["Kestrela", "Priya"])
    #expect(dictionary.misspelled(in: "Pria uses Kestrella.") == ["Priya", "Kestrela"])
  }
}
