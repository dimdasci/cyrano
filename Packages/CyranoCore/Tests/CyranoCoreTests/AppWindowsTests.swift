import Testing

@testable import CyranoCore

/// Which window Cyrano opens at launch, on a Dock click and when launched again (05 §1, §4).
@Suite struct AppWindowsTests {
  func setup(done: Bool = true, signedIn: Bool = true, accessibility: Bool = true) -> Setup {
    Setup(onboardingDone: done, signedIn: signedIn, hasAccessibility: accessibility)
  }

  @Test func onboardingShowsAtLaunchUntilDone() {
    let window: AppWindow? = setup(done: false).windowAtLaunch
    #expect(window == .onboarding)
  }

  @Test func launchOpensNoWindowOnceSetUp() {
    let window: AppWindow? = setup().windowAtLaunch
    #expect(window == nil)
  }

  @Test func launchOpensSettingsOnWhatWentMissing() {
    let signedOut: AppWindow? = setup(signedIn: false, accessibility: false).windowAtLaunch
    let noAccessibility: AppWindow? = setup(accessibility: false).windowAtLaunch
    #expect(signedOut == .settings(.account) && noAccessibility == .settings(.general))
  }

  @Test func reopenBringsThePanelForwardFirst() {
    let windows = ["Settings", "Proofreading"]
    let reopen: Reopen<String> = setup().reopen(windows, panel: "Proofreading")
    #expect(reopen == .show("Proofreading"))
  }

  @Test func reopenBringsTheFrontWindowForwardWithoutAPanel() {
    let reopen: Reopen<String> = setup().reopen(["About", "Settings"], panel: nil)
    #expect(reopen == .show("About"))
  }

  @Test func reopenWithNoWindowOpensSettings() {
    let reopen: Reopen<String> = setup().reopen([], panel: nil)
    let beforeDone: Reopen<String> = setup(done: false).reopen([], panel: nil)
    #expect(reopen == .open(.settings(nil)) && beforeDone == .open(.onboarding))
  }
}
