// Which window Cyrano opens by itself: at launch, on a click on its Dock icon and when it's
// launched again. See docs/specs/05-ui.md §1, §4.

/// A tab of Settings (05 §5).
public enum SettingsTab: String, CaseIterable, Sendable {
  case general, style, dictionary, prompts, account
}

/// A window Cyrano opens by itself.
public enum AppWindow: Hashable, Sendable {
  case onboarding
  /// Settings on a tab, or on the tab used last.
  case settings(SettingsTab?)
}

/// What a click on the Dock icon or launching Cyrano again does.
public enum Reopen<Window: Equatable>: Equatable {
  /// An open window comes forward; a minimized one comes back.
  case show(Window)
  case open(AppWindow)
}

/// Where the first setup stands. Onboarding shows until the user presses Done once; after that
/// everything it offers is in Settings.
public struct Setup: Sendable {
  public var onboardingDone: Bool
  public var signedIn: Bool
  public var hasAccessibility: Bool

  public init(onboardingDone: Bool, signedIn: Bool, hasAccessibility: Bool) {
    self.onboardingDone = onboardingDone
    self.signedIn = signedIn
    self.hasAccessibility = hasAccessibility
  }

  /// At launch, by hand or at login: no window once the setup is done, the Dock icon shows that
  /// Cyrano runs. Settings opens on what went missing since: the sign-in, then Accessibility.
  public var windowAtLaunch: AppWindow? {
    guard onboardingDone else { return .onboarding }
    if !signedIn { return .settings(.account) }
    if !hasAccessibility { return .settings(.general) }
    return nil
  }

  /// `windows` are Cyrano's open windows, front first, then the minimized ones. The Proofreading
  /// panel comes forward first; with no window open, Settings opens, or onboarding until it's
  /// done.
  public func reopen<Window: Equatable>(_ windows: [Window], panel: Window?) -> Reopen<Window> {
    if let panel, windows.contains(panel) { return .show(panel) }
    if let front = windows.first { return .show(front) }
    return .open(onboardingDone ? .settings(nil) : .onboarding)
  }
}
