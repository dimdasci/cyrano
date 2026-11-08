// App-wide state: account, models, style settings, and the entry points of a check.

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
  private(set) var signIn = SignInState.idle {
    didSet {
      if case .failed(let message) = signIn { VoiceOver.announce(message) }
    }
  }
  /// The model for each operation (02 M1).
  var models = ModelChoice(from: .standard) {
    didSet { models.save(to: .standard) }
  }
  var customInstructions: String = StoredSettings.customInstructions {
    didSet { StoredSettings.customInstructions = customInstructions }
  }
  /// Read who the user is writing to, what about and in which language from a screenshot of
  /// the window (02 C6).
  var readsContext: Bool = StoredSettings.readsContext {
    didSet { StoredSettings.readsContext = readsContext }
  }

  /// «Never change» terms, shared by every panel and Settings (02 M11).
  let dictionary = TermDictionary.standard()
  /// The user's prompts over the built-in ones, read by every call (02 M8).
  let prompts = PromptLibrary.standard()
  /// Context type, tone, level and language per app, from the panel header (05 §5).
  let appDefaults = AppDefaults()

  @ObservationIgnored private let auth = AuthService()
  /// The open panel; its action is also in the menu bar.
  @ObservationIgnored let panel = PanelController()
  @ObservationIgnored private let windows = WindowPresenter()
  @ObservationIgnored private var signInTask: Task<Void, Never>?

  func start() async {
    account = await auth.account
  }

  // MARK: Checks

  /// ⌥⌘G: the text of the field or selection, then Context read from its window. Without text
  /// the panel opens empty for the user to type or paste (02 C2, C6). The text is read while its
  /// app still has the keyboard. In Cyrano's own panel there is nothing else to check.
  func checkFocusedText() {
    guard let app = TextCapture.frontApp else {
      if !panel.isOpen { openPanel(for: TextCapture.manual("")) }
      return
    }
    Task {
      openPanel(for: await TextCapture.capture(from: app) ?? TextCapture.manual(""))
    }
  }

  func checkClipboard() {
    openPanel(for: TextCapture.fromClipboard() ?? TextCapture.manual(""))
  }

  func checkText() {
    openPanel(for: TextCapture.manual(""))
  }

  /// Opens the panel without checking: the user adds context first, then presses Check.
  private func openPanel(for captured: CapturedText) {
    panel.open(
      { [self] in
        let session = makeSession(for: captured)
        Task { await readContext(into: session, from: captured) }
        return PanelModel(session: session, captured: captured, app: self)
      }, near: captured.frame)
  }

  private func readContext(into session: ProofreadingSession, from captured: CapturedText) async {
    guard readsContext, let app = captured.source, CGPreflightScreenCaptureAccess(),
      let screenshot = await ScreenCapture.frontWindow(of: app)
    else { return }
    await session.readContext(from: screenshot)
  }

  private func makeSession(for captured: CapturedText) -> ProofreadingSession {
    var options = appDefaults.options(for: captured.bundleID)
    options.customInstructions = customInstructions
    return ProofreadingSession(
      original: captured.text, options: options, models: models, engine: makeEngine(),
      dictionary: dictionary, prompts: prompts)
  }

  private func makeEngine() -> any CorrectionEngine {
    OpenAIEngine(transport: URLSessionTransport()) { [auth] in
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
    case .notSaved:
      "Couldn't save the sign-in to the Keychain. Sign in again and allow access when macOS asks."
    case .invalidResponse(let detail): "Couldn't sign in (\(detail))."
    case nil: "Couldn't sign in."
    }
  }

  // MARK: Windows

  func showOnboarding() {
    windows.show(id: "onboarding", title: "Cyrano", size: CGSize(width: 520, height: 700)) {
      OnboardingView(app: self) { [windows] height in
        windows.fit(id: "onboarding", contentHeight: height)
      }
    }
  }

  func closeOnboarding() {
    windows.close(id: "onboarding")
  }

  func showAbout() {
    AppPresence.activate()
    NSApp.orderFrontStandardAboutPanel(options: [.credits: AboutCredits.text])
  }
}

/// Settings stored in UserDefaults. Tokens never go here (Keychain only).
private enum StoredSettings {
  static var customInstructions: String {
    get { UserDefaults.standard.string(forKey: "customInstructions") ?? "" }
    set { UserDefaults.standard.set(newValue, forKey: "customInstructions") }
  }

  static var readsContext: Bool {
    get { UserDefaults.standard.object(forKey: "readsContext") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "readsContext") }
  }
}
