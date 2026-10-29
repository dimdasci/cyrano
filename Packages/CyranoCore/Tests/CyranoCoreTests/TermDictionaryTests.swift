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
    let json = try String(contentsOf: file, encoding: .utf8)
    #expect(json.contains(#""term" : "Bitbucket""#))
    #expect(json.contains(#""added" : "2027-01-15T08:00:00Z""#))
  }

  @Test func noFileMeansAnEmptyDictionary() {
    #expect(TermDictionary(file: temporaryDictionaryFile()).terms.isEmpty)
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

  @Test func removingAndRenaming() {
    let dictionary = dictionary(["Bitbucket", "k8s", "Jira"])
    let removed = dictionary.remove("BitBucket")
    #expect(removed?.text == "Bitbucket")
    #expect(!dictionary.rename("k8s", to: "jira"))
    #expect(dictionary.rename("k8s", to: "K8s"))
    #expect(dictionary.terms.map(\.text) == ["K8s", "Jira"])
  }

  @Test func importReadsOneTermPerLine() {
    let dictionary = dictionary(["Bitbucket"])
    let count = dictionary.importTerms(from: "k8s\n\n  Jira \nbitbucket\r\nk8s\n")
    #expect(count == 2)
    #expect(dictionary.exported == "Bitbucket\nk8s\nJira\n")
  }

  @Test func aSelectionBecomesATerm() {
    #expect(TermDictionary.term(fromSelection: " Bitbucket. ") == "Bitbucket")
    #expect(TermDictionary.term(fromSelection: "“k8s”,") == "k8s")
    #expect(TermDictionary.term(fromSelection: "pull request") == "pull request")
    #expect(TermDictionary.term(fromSelection: "C++") == "C++")
    #expect(TermDictionary.term(fromSelection: "two\nlines") == nil)
    #expect(TermDictionary.term(fromSelection: " , ") == nil)
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
