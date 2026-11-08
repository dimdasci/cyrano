import Foundation
import Testing

@testable import CyranoCore

/// What VoiceOver announces and reads in the panel (05 §2.4, §7).
@MainActor @Suite struct VoiceOverTests {
  let grammar = Explanation(category: .grammar, reason: "Tense.")
  let style = Explanation(category: .style, reason: "Reads better.")

  func session(_ engine: FakeEngine, original: String = "I has a cat.") -> ProofreadingSession {
    ProofreadingSession(
      original: original, options: CheckOptions(), engine: engine, dictionary: dictionary())
  }

  /// Checks the text and returns everything VoiceOver was asked to say.
  func heard(_ engine: FakeEngine, original: String = "I has a cat.") async -> [String] {
    let session = session(engine, original: original)
    var heard: [String] = []
    session.announce = { heard.append($0) }
    await session.check()
    return heard
  }

  @Test func aNewCardIsAnnouncedWithItsChanges() async {
    let heard = await heard(FakeEngine(fixes: ["I have a cat."]))
    #expect(heard == ["Version 1, 1 change"])
  }

  @Test func aCorrectTextIsAnnouncedAsNeedingNoChanges() async {
    let heard = await heard(FakeEngine(fixes: ["Fine text."]), original: "Fine text.")
    #expect(heard == ["Version 1, no changes needed"])
  }

  @Test func anErrorIsAnnounced() async {
    let engine = FakeEngine(fixes: [])
    engine.failNextFix(with: .network)
    let heard = await heard(engine)
    #expect(heard == ["Couldn't reach OpenAI."])
  }

  @Test func anAnswerIsAnnouncedOnceWhole() async {
    let session = session(FakeEngine(fixes: ["I have a cat.", .answer("Yes, it is polite.")]))
    await session.check()
    var heard: [String] = []
    session.announce = { heard.append($0) }
    await session.send("Is this polite?")
    #expect(heard == ["Yes, it is polite."])
  }

  @Test func rejectingAChangeAnnouncesTheNewCard() async throws {
    let session = session(FakeEngine(fixes: ["I have a cat."]))
    await session.check()
    var heard: [String] = []
    session.announce = { heard.append($0) }
    let change = try #require(session.versions.last?.diff?.changes.first)
    session.reject(change)
    #expect(heard == ["Version 2, 1 change"])
  }

  @Test func theSummaryCountsFixesAndStyle() {
    let diff = TextDiff(old: "I has a big cat today.", new: "I have a big dog today.")
    let ready = version(.corrections(diff, .ready([1: grammar, 2: style])))
    let pending = version(.corrections(diff, .pending))
    let unexplained = version(.corrections(diff, .unavailable))
    let summaries: [String] = [ready.summary, pending.summary, unexplained.summary]
    #expect(summaries == ["1 fix · 1 style suggestion", "Explaining…", "2 changes"])
  }

  @Test func aCardWithoutChangesSaysSo() {
    let same = version(.corrections(TextDiff(old: "Fine.", new: "Fine."), .ready([:])))
    let translated = version(.translation(into: "German"))
    let summaries: [String] = [same.summary, translated.summary, translated.announcement]
    #expect(
      summaries == ["No changes needed", "Translated to German", "Version 1, translated to German"])
  }

  @Test func aChangeRowReadsTheEditItsKindAndReason() {
    let replaced = Change(id: 1, old: "has", new: "have").spoken(reason: grammar)
    let added = Change(id: 2, old: "", new: "really ").spoken(reason: nil)
    let removed = Change(id: 3, old: "very ", new: "").spoken(reason: style)
    #expect(replaced == "has, replaced with have, error. Tense.")
    #expect(added == "really, added, error")
    #expect(removed == "very, removed, style suggestion. Reads better.")
  }

  /// The card shows "I has have a cat."; VoiceOver reads "I have a cat." and maps a range of one
  /// to the other.
  @Test func theCardReadsWithoutRemovedWords() {
    let layout = DiffLayout(TextDiff(old: "I has a cat.", new: "I have a cat."))
    let texts: [String] = [layout.pieces.map(\.text).joined(), layout.spoken]
    let have: NSRange = layout.spokenRange(NSRange(location: 6, length: 4))
    let shownHave: NSRange = layout.shownRange(NSRange(location: 2, length: 4))
    let whole: NSRange = layout.shownRange(NSRange(location: 0, length: 13))
    #expect(texts == ["I has have a cat.", "I have a cat."])
    #expect(have == NSRange(location: 2, length: 4) && shownHave == NSRange(location: 6, length: 4))
    #expect(whole == NSRange(location: 0, length: 17))
  }

  private func version(_ edit: Version.Edit) -> Version {
    Version(number: 1, text: "", edit: edit, origin: .check)
  }
}
