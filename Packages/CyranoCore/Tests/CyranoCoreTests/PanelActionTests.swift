import Foundation
import Testing

@testable import CyranoCore

/// The one button by the dialog field: Check or Send, and what each sends (05 §2.7).
@MainActor @Suite struct PanelActionTests {
  func session(_ engine: FakeEngine, original: String = "I has a cat.") -> ProofreadingSession {
    ProofreadingSession(
      original: original, context: "Do you have pets?", options: CheckOptions(), engine: engine)
  }

  @Test func actionIsCheckBeforeTheFirstCheck() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."])
    let session = session(engine)
    #expect(session.action(for: "") == .check)
    #expect(session.canPerform(message: ""))

    await session.perform(message: "")
    let input = try #require(engine.fixCalls.first?.input)
    #expect(input.count == 1)
    #expect(input[0].text.contains("Do you have pets?"))
    #expect(session.versions.last?.origin == .check)
  }

  @Test func actionIsSendWhileTheContextIsUnchanged() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    #expect(session.action(for: "") == .send)
    #expect(!session.canPerform(message: "  "))
    #expect(session.action(for: "make it two cats") == .send)
    #expect(session.canPerform(message: "make it two cats"))

    await session.perform(message: "make it two cats")
    let input = try #require(engine.fixCalls.last?.input)
    #expect(input.map(\.role) == [.user, .assistant, .user])
    #expect(input[0].text.contains("Do you have pets?"))
    #expect(input[2].text.contains("make it two cats"))
    #expect(session.versions.last?.origin == .request)
  }

  @Test func changedContextWithAnEmptyFieldRechecks() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have a cat!"])
    let session = session(engine)
    await session.check()
    session.context = "Any pets at home?"
    #expect(session.action(for: "") == .check)
    #expect(session.canPerform(message: ""))

    await session.perform(message: "")
    let input = try #require(engine.fixCalls.last?.input)
    #expect(input[0].text.contains("Any pets at home?"))
    #expect(input.last?.text == Prompts.recheck)
    #expect(session.versions.last?.origin == .recheck)
    #expect(session.action(for: "") == .send)
  }

  @Test func changedImagesWithAnEmptyFieldRecheck() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have a cat!"])
    let session = session(engine)
    session.images = [imageA]
    await session.check()
    session.images = [imageA]
    #expect(session.action(for: "") == .send)
    session.images.append(imageB)
    #expect(session.action(for: "") == .check)

    await session.perform(message: "")
    let input = try #require(engine.fixCalls.last?.input)
    #expect(input[0].images == [imageA, imageB])
    #expect(input.last?.text == Prompts.recheck)
  }

  @Test func changedContextWithAMessageSendsBoth() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    session.context = "How many pets?"
    #expect(session.action(for: "make it two cats") == .send)

    await session.perform(message: "make it two cats")
    let input = try #require(engine.fixCalls.last?.input)
    #expect(input.count == 3)
    #expect(input[0].text.contains("How many pets?"))
    #expect(input[2].text.contains("make it two cats"))
    #expect(session.versions.last?.origin == .request)
    #expect(session.action(for: "") == .send)
  }

  @Test func actionIsDisabledWhileACheckRuns() async {
    let engine = FakeEngine(fixes: ["I have a cat."])
    let session = session(engine)
    engine.holdFixes()
    let check = Task { await session.perform(message: "") }
    while engine.fixCalls.isEmpty { await Task.yield() }

    #expect(!session.canPerform(message: ""))
    engine.release()
    await check.value
    #expect(!session.canPerform(message: ""))
    #expect(session.canPerform(message: "two cats"))
  }

  @Test func emptyTextCannotBeChecked() async throws {
    let engine = FakeEngine(fixes: ["I have a cat."])
    let session = session(engine, original: "")
    #expect(session.action(for: "") == .check)
    #expect(!session.canPerform(message: ""))

    session.original = "I has a cat."
    #expect(session.canPerform(message: ""))
    await session.perform(message: "")
    let input = try #require(engine.fixCalls.first?.input)
    #expect(input[0].text.hasSuffix("TEXT:\n\"\"\"\nI has a cat.\n\"\"\""))
    #expect(session.versions.first?.diff?.changes.map(\.words) == [["has", "have"]])
  }
}
