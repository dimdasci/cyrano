import Testing

@testable import CyranoCore

/// Settings → General → Language: the system's language or one of Cyrano's, stored as the app's
/// own AppleLanguages, the same value System Settings sets for one app (05 §5, §6).
@Suite struct LanguageChoiceTests {
  let spanish = InterfaceLanguage(preferences: ["es"])
  let russian = InterfaceLanguage(preferences: ["ru"])

  @Test func thePopUpOffersTheSystemAndEachLanguageInItself() {
    let names: [String] = LanguageChoice.all.compactMap { choice in
      guard case .fixed(let language) = choice else { return nil }
      return language.ownName
    }
    #expect(LanguageChoice.all.first == .system)
    #expect(names == ["English", "Español", "Русский"])
  }

  @Test func theChoiceIsReadFromTheAppsLanguages() {
    let stored: [[String]?] = [nil, [], ["es"], ["ru-RU"]]
    let choices: [LanguageChoice] = stored.map(LanguageChoice.init(appLanguages:))
    #expect(choices == [.system, .system, .fixed(spanish), .fixed(russian)])
  }

  @Test func theSystemRemovesTheAppsLanguages() {
    let stored: [[String]?] = [LanguageChoice.system, .fixed(russian)].map(\.appLanguages)
    #expect(stored == [nil, ["ru"]])
  }

  @Test func theSystemFollowsTheMacWithEnglishForAnyOtherLanguage() {
    let onMac: [String] = [["de-DE", "ru-RU"], ["pt-BR"]].map {
      LanguageChoice.system.language(system: $0).code
    }
    #expect(onMac == ["ru", "en"])
  }

  @Test func aLanguageWinsOverTheMacs() {
    #expect(LanguageChoice.fixed(spanish).language(system: ["ru"]) == spanish)
  }

  @Test func aNewLanguageWaitsForARelaunch() {
    let running = russian
    let relaunch: [Bool] = [LanguageChoice.fixed(spanish), .fixed(russian), .system].map {
      $0.needsRelaunch(running: running, system: ["ru-RU"])
    }
    #expect(relaunch == [true, false, false])
  }
}
