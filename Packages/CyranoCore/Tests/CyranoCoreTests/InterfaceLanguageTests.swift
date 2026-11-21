import Testing

@testable import CyranoCore

/// Runs a suite or a test in English, whatever language the Mac running the tests is in: for
/// tests that check what the app says.
struct InEnglish: SuiteTrait, TestTrait, TestScoping {
  var isRecursive: Bool { true }

  func provideScope(
    for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
  ) async throws {
    try await InterfaceLanguage.$current.withValue(InterfaceLanguage(preferences: ["en"])) {
      try await function()
    }
  }
}

extension Trait where Self == InEnglish {
  static var inEnglish: Self { InEnglish() }
}

/// Runs `body` as Cyrano does for a user whose languages are `preferences`.
func speaking<T>(_ preferences: String..., body: () throws -> T) rethrows -> T {
  try InterfaceLanguage.$current.withValue(
    InterfaceLanguage(preferences: preferences), operation: body)
}

/// The interface speaks the first of the user's languages Cyrano has, English for any other, and
/// texts with numbers follow the plural rules of that language (05 §6).
@MainActor @Suite struct InterfaceLanguageTests {
  @Test func theFirstLanguageCyranoSpeaksWins() {
    let preferences: [[String]] = [["de-DE", "ru-RU"], ["es-MX"], ["en-GB", "ru"], ["pt-BR"], []]
    let codes: [String] = preferences.map { InterfaceLanguage(preferences: $0).code }
    #expect(codes == ["ru", "es", "en", "en", "en"])
  }

  @Test func russianCountsByItsPluralRules() {
    let summaries: [String] = [1, 2, 5, 21].map { count in
      speaking("ru") { fixed(count).summary }
    }
    #expect(summaries == ["1 исправление", "2 исправления", "5 исправлений", "21 исправление"])
  }

  @Test func spanishCountsFixesAndStyle() {
    let summary: String = speaking("es-ES") { fixed(1, style: 2).summary }
    #expect(summary == "1 corrección · 2 sugerencias de estilo")
  }

  @Test func anotherLanguageGetsEnglish() {
    let summary: String = speaking("de-DE") { fixed(2, style: 1).summary }
    #expect(summary == "2 fixes · 1 style suggestion")
  }

  @Test func aTranslationNamesTheLanguageInTheInterfaceLanguage() {
    let german = Version(number: 1, text: "", edit: .translation(into: "de"), origin: .check)
    let spanish: String = speaking("es") { german.summary }
    let russian: String = speaking("ru") { german.announcement }
    #expect(spanish == "Traducido al alemán")
    #expect(russian == "Версия 1, переведена на немецкий")
  }

  @Test func aChangeRowSpeaksTheInterfaceLanguage() {
    let reason = Explanation(category: .grammar, reason: "Время глагола.")
    let row: String = speaking("ru") {
      Change(id: 1, old: "has", new: "have").spoken(reason: reason)
    }
    #expect(row == "has, заменено на have, ошибка. Время глагола.")
  }

  /// `count` errors fixed and `style` style changes, each with its reason.
  private func fixed(_ count: Int, style: Int = 0) -> Version {
    let words = (1...(count + style)).map { "word\($0) and so" }
    let new = words.map { $0.replacing("word", with: "text") }
    let diff = TextDiff(old: words.joined(separator: " "), new: new.joined(separator: " "))
    let reasons = Dictionary(
      uniqueKeysWithValues: diff.changes.map { change in
        let category: Explanation.Category = change.id <= count ? .grammar : .style
        return (change.id, Explanation(category: category, reason: ""))
      })
    return Version(
      number: 1, text: diff.newText, edit: .corrections(diff, .ready(reasons)), origin: .check)
  }
}

/// Announcements and explanations come in the interface language (02 M7, 04 §4.4).
@MainActor @Suite struct InterfaceLanguageSessionTests {
  func check(speaking preferences: String) async -> (FakeEngine, [String]) {
    let engine = FakeEngine(fixes: ["I have a cat."])
    let session = ProofreadingSession(
      original: "I has a cat.", options: CheckOptions(), engine: engine, dictionary: dictionary())
    var heard: [String] = []
    session.announce = { heard.append($0) }
    await InterfaceLanguage.$current.withValue(InterfaceLanguage(preferences: [preferences])) {
      await session.check()
    }
    return (engine, heard)
  }

  @Test func explanationsAreAskedForInTheInterfaceLanguage() async {
    let (russian, _) = await check(speaking: "ru")
    let (german, _) = await check(speaking: "de")
    let explain: [String] = [russian, german].compactMap { $0.calls.last?.instructions }
    let builtIn: [Bool] = explain.map { $0.hasPrefix(Prompts.explain) }
    let lastLines: [String] = explain.compactMap { $0.split(separator: "\n").last.map(String.init) }
    #expect(builtIn == [true, true])
    #expect(lastLines == ["Write every reason in Russian.", "Write every reason in English."])
  }

  @Test func aNewCardIsAnnouncedInTheInterfaceLanguage() async {
    let (_, heard) = await check(speaking: "es")
    #expect(heard == ["Versión 1, 1 cambio"])
  }
}
