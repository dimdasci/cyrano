// App-wide state: account, model choice, style settings, and the entry points of a check.

import AppKit
import CyranoCore
import Observation
import SwiftUI

@Observable
final class AppModel {
  enum SignInState: Equatable {
    case idle
    case waiting
    case failed(String)
  }

  private(set) var account: Account?
  private(set) var signIn = SignInState.idle
  var model: Model = StoredSettings.model {
    didSet { StoredSettings.model = model }
  }
  var customInstructions: String = StoredSettings.customInstructions {
    didSet { StoredSettings.customInstructions = customInstructions }
  }

  @ObservationIgnored private let auth = AuthService()
  @ObservationIgnored private let panel = PanelController()
  @ObservationIgnored private let windows = WindowPresenter()
  @ObservationIgnored private var signInTask: Task<Void, Never>?

  func start() async {
    account = await auth.account
  }

  // MARK: Checks

  func checkFocusedText() {
    Task {
      guard let app = TextCapture.frontApp else { return showNothingToCheck() }
      if let captured = await TextCapture.capture(from: app) { return openPanel(for: captured) }
      await checkScreen(of: app)
    }
  }

  /// Nothing could be read or copied: let the model read the draft from a screenshot.
  private func checkScreen(of app: NSRunningApplication) async {
    panel.show(PanelModel(content: .readingScreen, app: self), near: nil)
    guard let screenshot = await ScreenCapture.frontWindow(of: app),
      let text = try? await ScreenReading.draft(in: screenshot, engine: makeEngine())
    else { return showNothingToCheck() }
    openPanel(for: TextCapture.fromScreen(text, app: app))
  }

  private func showNothingToCheck() {
    panel.show(PanelModel(content: .nothingToCheck, app: self), near: nil)
  }

  func checkClipboard() {
    guard let captured = TextCapture.fromClipboard() else { return showNothingToCheck() }
    openPanel(for: captured)
  }

  func showManualCheck() {
    windows.show(id: "manual", title: "Check Text", size: CGSize(width: 600, height: 560)) {
      ManualCheckView(app: self)
    }
  }

  /// Opens the panel without checking: the user adds context first, then presses Check.
  func openPanel(for captured: CapturedText) {
    let session = makeSession(for: captured)
    panel.show(PanelModel(content: .session(session, captured), app: self), near: captured.frame)
  }

  func makeSession(for captured: CapturedText) -> ProofreadingSession {
    var options = OptionsMemory.options(for: captured.bundleID)
    options.customInstructions = customInstructions
    return ProofreadingSession(original: captured.text, options: options, engine: makeEngine())
  }

  private func makeEngine() -> any CorrectionEngine {
    OpenAIEngine(model: model, transport: URLSessionTransport()) { [auth] in
      try await auth.accessToken()
    }
  }

  // MARK: Account

  func signInWithChatGPT(then next: (() -> Void)? = nil) {
    signIn = .waiting
    signInTask = Task {
      do {
        account = try await auth.signIn { url in
          Task { @MainActor in NSWorkspace.shared.open(url) }
        }
        signIn = .idle
        next?()
      } catch {
        signIn = Task.isCancelled ? .idle : .failed(Self.message(for: error))
      }
    }
  }

  func cancelSignIn() {
    signInTask?.cancel()
    signIn = .idle
  }

  func signOut() async {
    await auth.signOut()
    account = nil
  }

  /// Called when the API says the token is gone.
  func markSignedOut() {
    account = nil
  }

  private static func message(for error: any Error) -> String {
    switch error as? AuthError {
    case .cancelled: "Sign-in was cancelled."
    case .planNotAllowed: "Your plan doesn't allow apps to use it. Plus or Pro is required."
    case .network: "Couldn't reach OpenAI."
    case .invalidResponse(let detail): "Couldn't sign in (\(detail))."
    case nil: "Couldn't sign in."
    }
  }

  // MARK: Windows

  func showOnboarding() {
    windows.show(id: "onboarding", title: "Cyrano", size: CGSize(width: 520, height: 440)) {
      OnboardingView(app: self)
    }
  }

  func closeOnboarding() {
    windows.close(id: "onboarding")
  }

  func showAbout() {
    NSApp.activate()
    NSApp.orderFrontStandardAboutPanel(options: [.credits: AboutCredits.text(model: model)])
  }
}

/// Settings stored in UserDefaults. Tokens never go here (Keychain only).
private enum StoredSettings {
  static var model: Model {
    get { UserDefaults.standard.string(forKey: "model").flatMap(Model.init) ?? .sol }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: "model") }
  }

  static var customInstructions: String {
    get { UserDefaults.standard.string(forKey: "customInstructions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "customInstructions") }
  }
}

/// Context type, tone, level and language per app (bundle id). See docs/specs/02 S2.
enum OptionsMemory {
  static func options(for bundleID: String?) -> CheckOptions {
    guard let data = UserDefaults.standard.data(forKey: key(bundleID)),
      let options = try? JSONDecoder().decode(CheckOptions.self, from: data)
    else { return CheckOptions() }
    return options
  }

  static func remember(_ options: CheckOptions, for bundleID: String?) {
    var stored = options
    stored.customInstructions = ""
    UserDefaults.standard.set(try? JSONEncoder().encode(stored), forKey: key(bundleID))
  }

  private static func key(_ bundleID: String?) -> String {
    "options.\(bundleID ?? "manual")"
  }
}
