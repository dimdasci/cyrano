import Foundation
import Testing

@testable import CyranoCore

/// Dictionary terms found in the text go to Fix in the first message's <dictionary> (04 §4.2).
@MainActor @Suite struct DictionaryPromptTests {
  func session(
    _ engine: FakeEngine, terms: [String], original: String = "I pushed it to bitbucket and K8S."
  ) -> ProofreadingSession {
    ProofreadingSession(
      original: original, options: CheckOptions(), engine: engine, dictionary: dictionary(terms))
  }

  func firstMessage(of call: ModelCall?) throws -> String {
    try #require(call?.input.first?.text)
  }

  @Test func theFirstMessageKeepsOnlyTermsFoundInTheText() async throws {
    let engine = FakeEngine(fixes: ["I pushed it to Bitbucket and K8S."])
    await session(engine, terms: ["Jira", "k8s", "Bitbucket"]).check()
    let message = try firstMessage(of: engine.fixCalls.first)
    #expect(
      message.hasPrefix(
        "<dictionary>\nKeep these words exactly as written: \"Bitbucket\", \"k8s\".\n</dictionary>"
      ))
  }

  @Test func aTermSpelledDifferentlyGoesAsASpellingHint() async throws {
    let engine = FakeEngine(fixes: ["Ask Priya about Bitbucket."])
    await session(engine, terms: ["Priya", "Bitbucket"], original: "Ask Pria about Bitbucket.")
      .check()
    let message = try firstMessage(of: engine.fixCalls.first)
    #expect(
      message.contains(
        "Keep these words exactly as written: \"Bitbucket\".\n"
          + "These terms may be misspelled in the text; where the text means one, spell it so: "
          + "\"Priya\".\n</dictionary>"))
  }

  @Test func withoutTermsInTheTextThereIsNoLine() async throws {
    let engine = FakeEngine(fixes: ["I pushed it to Bitbucket and K8S."])
    await session(engine, terms: ["Jira"]).check()
    let message = try firstMessage(of: engine.fixCalls.first)
    #expect(!message.contains("<dictionary>"))
  }

  @Test func aTermAddedAfterACheckGoesWithTheNextRequest() async throws {
    let engine = FakeEngine(fixes: ["I pushed it to Bitbucket and K8S.", "Pushed to Bitbucket."])
    let session = session(engine, terms: [])
    await session.check()
    session.dictionary.add("k8s")
    await session.perform(message: "make it shorter")
    #expect(try !firstMessage(of: engine.fixCalls.first).contains("Keep these words"))
    #expect(try firstMessage(of: engine.fixCalls.last).contains("written: \"k8s\".\n</dict"))
  }

  /// Never Change in Text to check (05 §2.4): the user edits the text, adds a word from it, and
  /// the first check already keeps it.
  @Test func aTermAddedBeforeTheFirstCheckGoesWithIt() async throws {
    let engine = FakeEngine(fixes: ["Ask Luna about Grafana."])
    let session = session(engine, terms: [], original: "Ask luna.")
    session.original = "Ask luna about grafana."
    let term = try #require(TermDictionary.term(fromSelection: " grafana."))
    session.dictionary.add(term)
    await session.check()
    #expect(try firstMessage(of: engine.fixCalls.first).contains("written: \"grafana\".\n</"))
  }

  /// "k8s" checked into "Kubernetes": the session and its one change.
  func checkedK8s() async throws -> (ProofreadingSession, Change) {
    let engine = FakeEngine(fixes: ["Deploy it to Kubernetes today."])
    let session = session(engine, terms: [], original: "Deploy it to k8s today.")
    await session.check()
    let change = try #require(session.versions.last?.diff?.changes.first)
    return (session, change)
  }

  @Test func neverChangeRejectsTheChangeAndAddsTheTerm() async throws {
    let (session, change) = try await checkedK8s()

    #expect(session.neverChange(change, keeping: "k8s"))
    #expect(session.latestText == "Deploy it to k8s today.")
    #expect(session.versions.last?.origin == .rejection)
    #expect(session.dictionary.contains("k8s"))
  }
}

/// The words a change row offers to keep (05 §2.4).
@Suite struct ChangeTermTests {
  func terms(_ old: String, _ new: String) -> [String] {
    TextDiff(old: old, new: new).changes.first?.terms ?? []
  }

  @Test func aReplacedWordIsTheTerm() {
    #expect(terms("Deploy to k8s today", "Deploy to Kubernetes today") == ["k8s"])
  }

  @Test func eachChangedWordOfAMergedChangeIsATerm() {
    #expect(
      terms("logs are in kibana, take a look", "logs are in Kibana. Take a look") == [
        "kibana", "take",
      ])
  }

  @Test func wordsTheNewTextKeepsAreNotTerms() {
    #expect(terms("I pushed it to Github, can you", "I pushed it to Github. Can you") == ["can"])
  }

  @Test func anInsertedWordHasNoTerm() {
    #expect(terms("I have cat.", "I have a cat.") == [])
  }
}
