import Foundation
import Testing

@testable import CyranoCore

/// Dictionary terms found in the text go to Fix as one line of the first message (04 §4.2).
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
      message.hasSuffix("\"\"\"\nKeep these words exactly as written: \"Bitbucket\", \"k8s\"."))
  }

  @Test func withoutTermsInTheTextThereIsNoLine() async throws {
    let engine = FakeEngine(fixes: ["I pushed it to Bitbucket and K8S."])
    await session(engine, terms: ["Jira"]).check()
    #expect(try !firstMessage(of: engine.fixCalls.first).contains("Keep these words"))
  }

  @Test func theLineComesBeforeTheImagesNote() async throws {
    let engine = FakeEngine(fixes: ["I pushed it to Bitbucket and K8S."])
    let session = session(engine, terms: ["k8s"])
    session.images = [imageA]
    await session.check()
    let message = try firstMessage(of: engine.fixCalls.first)
    #expect(message.hasSuffix("written: \"k8s\".\n" + Prompts.imagesNote))
  }

  @Test func aTermAddedAfterACheckGoesWithTheNextRequest() async throws {
    let engine = FakeEngine(fixes: ["I pushed it to Bitbucket and K8S.", "Pushed to Bitbucket."])
    let session = session(engine, terms: [])
    await session.check()
    session.dictionary.add("k8s")
    await session.perform(message: "make it shorter")
    #expect(try !firstMessage(of: engine.fixCalls.first).contains("Keep these words"))
    #expect(try firstMessage(of: engine.fixCalls.last).hasSuffix("written: \"k8s\"."))
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

  @Test func neverChangeKeepsOnlyWordsOfTheChange() async throws {
    let (session, change) = try await checkedK8s()

    #expect(!session.neverChange(change, keeping: "today"))
    #expect(session.versions.count == 1)
    #expect(session.dictionary.terms.isEmpty)
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
