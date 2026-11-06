import Foundation
import Testing

@testable import CyranoCore

/// UserDefaults of a test's own, removed with it.
final class TestDefaults {
  let name = "cyrano-tests-\(UUID().uuidString)"
  let defaults: UserDefaults

  init() throws {
    defaults = try #require(UserDefaults(suiteName: name))
  }

  deinit { defaults.removePersistentDomain(forName: name) }
}

extension ModelCall {
  fileprivate var explains: Bool { instructions == Prompts.explain }
  fileprivate var onTerra: Bool { model == Model.terra }
}

/// Each kind of call goes to the model chosen for it in Settings (02 M1).
@MainActor @Suite struct ModelChoiceTests {
  let stored: TestDefaults

  init() throws { stored = try TestDefaults() }

  @Test func eachCallGoesToItsModel() async {
    let engine = await dialog(
      with: ModelChoice(context: .sol, proofreading: .terra, explanations: .luna))

    // Reading the context, two explanations, and three Fix calls: check, answer, new version.
    let context: [Model] = engine.contextCalls.map(\.model)
    let explanations: [Model] = engine.calls.filter(\.explains).map(\.model)
    let proofreading: [Model] = engine.calls.filter(\.onTerra).map(\.model)
    let routed: [[Model]] = [context, explanations, proofreading]
    let expected: [[Model]] = [[.sol], [.luna, .luna], Array(repeating: .terra, count: 3)]
    let calls: Int = engine.calls.count

    #expect(calls == 6)
    #expect(routed == expected)
  }

  /// Reads the context, checks, asks a question and asks for a change.
  private func dialog(with models: ModelChoice) async -> FakeEngine {
    let engine = FakeEngine(fixes: ["I have a cat.", .answer("Yes."), "I have two cats."])
    let session = ProofreadingSession(
      original: "I has a cat.", options: CheckOptions(), models: models, engine: engine,
      dictionary: dictionary())
    await session.readContext(from: imageA)
    await session.check()
    await session.send("Is it polite?")
    await session.send("two cats")
    return engine
  }

  @Test func withoutAChoiceContextGoesToTerraAndTheRestToSol() {
    let models = ModelChoice(from: stored.defaults)
    #expect(models == ModelChoice(context: .terra, proofreading: .sol, explanations: .sol))
  }

  @Test func theChoiceIsKeptForEachOperation() {
    ModelChoice(context: .terra, proofreading: .luna, explanations: .terra).save(
      to: stored.defaults)
    let models = ModelChoice(from: stored.defaults)
    #expect(models == ModelChoice(context: .terra, proofreading: .luna, explanations: .terra))
  }

  /// Before 0.5 one model did everything; it stays the proofreading model.
  @Test func theEarlierChoiceBecomesTheProofreadingModel() {
    stored.defaults.set("gpt-6-luna", forKey: "model")
    #expect(ModelChoice(from: stored.defaults).proofreading == .luna)
  }

  @Test func aModelNoLongerOfferedFallsBackToTheDefault() {
    stored.defaults.set("gpt-5.6-sol", forKey: "model")
    stored.defaults.set("gpt-6.1-luna", forKey: "model.context")
    let models = ModelChoice(from: stored.defaults)
    #expect(models.proofreading == .sol)
    #expect(models.context == .terra)
  }
}
