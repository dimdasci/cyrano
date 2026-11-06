import Foundation
import Testing

@testable import CyranoCore

/// The one button by the dialog field: Check or Send, and what each sends (05 §2.7).
@MainActor @Suite struct PanelActionTests {
  func session(_ engine: FakeEngine, original: String = "I has a cat.") -> ProofreadingSession {
    ProofreadingSession(
      original: original, context: "Do you have pets?", options: CheckOptions(), engine: engine,
      dictionary: dictionary())
  }

  @Test func actionIsCheckBeforeTheFirstCheck() async {
    let session = session(FakeEngine(fixes: ["I have a cat."]))
    let action: ProofreadingSession.Action = session.action(for: "")
    let enabled: Bool = session.canPerform(message: "")
    #expect(action == ProofreadingSession.Action.check && enabled)

    await session.perform(message: "")
    let origin: Version.Origin? = session.versions.last?.origin
    #expect(origin == Version.Origin.check)
  }

  @Test func actionIsSendWhileTheContextIsUnchanged() async throws {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    #expect(session.action(for: "") == .send)
    #expect(!session.canPerform(message: "  "))
    #expect(session.canPerform(message: "make it two cats"))

    await session.perform(message: "make it two cats")
    let first = try #require(engine.fixCalls.last?.input.first)
    #expect(first.text.contains("Do you have pets?"))
    #expect(session.versions.last?.origin == .request)
  }

  @Test func changedContextWithAnEmptyFieldRechecks() async {
    let press = await press("", afterContextChangesTo: "Any pets at home?")
    #expect(press.label == ProofreadingSession.Action.check)
    #expect(press.firstMessage.contains("Any pets at home?"))
    #expect(press.lastMessage == Prompts.recheck)
    #expect(press.origin == Version.Origin.recheck && press.nextLabel == .send)
  }

  @Test func changedImagesWithAnEmptyFieldRecheck() async {
    let session = session(FakeEngine(fixes: ["I have a cat."]))
    session.images = [imageA]
    await session.check()
    session.images = [imageA]
    #expect(session.action(for: "") == .send)
    session.images.append(imageB)
    #expect(session.action(for: "") == .check)
  }

  @Test func changedContextWithAMessageSendsBoth() async {
    let press = await press("make it two cats", afterContextChangesTo: "How many pets?")
    #expect(press.label == ProofreadingSession.Action.send && press.messages == 3)
    #expect(press.firstMessage.contains("How many pets?"))
    #expect(press.lastMessage.contains("make it two cats"))
    #expect(press.origin == Version.Origin.request && press.nextLabel == .send)
  }

  /// What a press of the action button sent after the context changed, and where it left the
  /// panel.
  struct Press {
    let label: ProofreadingSession.Action
    let messages: Int
    let firstMessage: String
    let lastMessage: String
    let origin: Version.Origin?
    let nextLabel: ProofreadingSession.Action
  }

  /// Checks, changes the context, then presses the button with `message` in the field.
  func press(_ message: String, afterContextChangesTo context: String) async -> Press {
    let engine = FakeEngine(fixes: ["I have a cat.", "I have two cats."])
    let session = session(engine)
    await session.check()
    session.context = context
    let label = session.action(for: message)
    await session.perform(message: message)
    let input: [String] = engine.fixCalls.last?.input.map(\.text) ?? []
    return Press(
      label: label, messages: input.count, firstMessage: input.first ?? "",
      lastMessage: input.last ?? "", origin: session.versions.last?.origin,
      nextLabel: session.action(for: ""))
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
    #expect(input[0].text.hasSuffix("<text>\nI has a cat.\n</text>"))
    #expect(session.versions.first?.diff?.changes.map(\.words) == [["has", "have"]])
  }
}
