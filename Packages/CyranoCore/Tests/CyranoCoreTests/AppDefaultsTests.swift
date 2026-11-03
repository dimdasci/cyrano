import Foundation
import Testing

@testable import CyranoCore

/// Context type, tone and level remembered per app from the panel (05 §2.3, §5).
@MainActor @Suite struct AppDefaultsTests {
  let stored: TestDefaults
  let slack = "com.tinyspeck.slackmacgap"
  let mail = "com.apple.mail"
  let casual = CheckOptions(tone: .casual)
  let formal = CheckOptions(textType: .email, tone: .professional, level: .errorsOnly)

  init() throws { stored = try TestDefaults() }

  @Test func optionsAreRememberedForTheirAppAcrossLaunches() {
    AppDefaults(defaults: stored.defaults).remember(casual, for: slack)

    let restarted = AppDefaults(defaults: stored.defaults)
    #expect(restarted.options(for: slack) == casual)
    #expect(restarted.options(for: mail) == CheckOptions())
  }

  @Test func customInstructionsStayInStyle() {
    var options = casual
    options.customInstructions = "No emoji."
    let apps = AppDefaults(defaults: stored.defaults)
    apps.remember(options, for: slack)
    #expect(apps.options(for: slack).customInstructions.isEmpty)
  }

  /// The language follows the conversation, not the app (02 M7).
  @Test func languageIsNotRemembered() {
    var spanish = casual
    spanish.language = .spanish
    AppDefaults(defaults: stored.defaults).remember(spanish, for: slack)

    #expect(AppDefaults(defaults: stored.defaults).options(for: slack) == casual)
  }

  @Test func languageSavedBeforeIsIgnored() throws {
    let saved = CheckOptions(tone: .casual, language: .russian)
    stored.defaults.set(try JSONEncoder().encode(saved), forKey: "options.\(slack)")

    #expect(AppDefaults(defaults: stored.defaults).options(for: slack) == casual)
  }

  @Test func eachAppIsOneRowWithItsLatestValues() {
    let apps = AppDefaults(defaults: stored.defaults)
    apps.remember(CheckOptions(), for: slack)
    apps.remember(casual, for: slack)
    apps.remember(formal, for: nil)

    let rows = Set(apps.entries)
    #expect(
      rows == [.init(bundleID: slack, options: casual), .init(bundleID: nil, options: formal)])
  }

  @Test func resetGoesBackToTheDefaultsAndRemovesTheRow() {
    let apps = AppDefaults(defaults: stored.defaults)
    apps.remember(casual, for: slack)
    apps.remember(formal, for: mail)
    apps.reset(slack)

    let restarted = AppDefaults(defaults: stored.defaults)
    #expect(restarted.options(for: slack) == CheckOptions())
    #expect(restarted.entries.map(\.bundleID) == [mail])
    #expect(apps.entries.map(\.bundleID) == [mail])
  }
}
