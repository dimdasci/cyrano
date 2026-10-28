import Foundation
import Synchronization
import Testing

@testable import CyranoCore

final class MemoryCredentialStore: CredentialStore {
  private let value: Mutex<Credentials?>

  init(_ credentials: Credentials? = nil) { value = Mutex(credentials) }

  func load() -> Credentials? { value.withLock { $0 } }
  func save(_ credentials: Credentials) throws { value.withLock { $0 = credentials } }
  func delete() { value.withLock { $0 = nil } }
}

@Suite struct AuthorizationTests {
  @Test func pkceChallengeIsBase64URLOfSHA256() {
    let attempt = AuthorizationAttempt(verifier: "dBjftJeZ4CVP-mJ92K9pVAzcjzBIzfrcWnrEj6uRWEs")
    // Reference: printf <verifier> | openssl dgst -sha256 -binary | base64, in base64url.
    #expect(attempt.challenge == "7zmrA8lHAaVlJBhw7PhL6BECnEF9Uc4g9IzzYTSTh_w")
  }

  @Test func firstSignInAsksForADynamicClient() throws {
    let url = try AuthorizationAttempt().authorizeURL(
      clientID: "dynamic_agent_client", hostID: "urn:uuid:1", email: nil)
    let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
    #expect(url.host() == "auth.openai.com")
    #expect(values["agent_name_hint"] == "Cyrano")
    #expect(values["code_challenge_method"] == "S256")
    #expect(values["redirect_uri"] == "http://127.0.0.1:1457/auth/callback")
    #expect(values["scope"]?.contains("chatgpt.tokens.use.direct") == true)
  }

  @Test func callbackGivesCodeAndIssuedClient() throws {
    let attempt = AuthorizationAttempt(state: "s1")
    let accepted = try attempt.accept(
      ["state": "s1", "code": "c1", "client_id": "oaiapp_1"],
      requestedClientID: "dynamic_agent_client")
    #expect(accepted.code == "c1")
    #expect(accepted.clientID == "oaiapp_1")
  }

  @Test func callbackRejectsWrongStateAndDenial() {
    let attempt = AuthorizationAttempt(state: "s1")
    #expect(throws: AuthError.self) {
      try attempt.accept(["state": "other", "code": "c"], requestedClientID: "oaiapp_1")
    }
    #expect(throws: AuthError.cancelled) {
      try attempt.accept(["state": "s1", "error": "access_denied"], requestedClientID: "oaiapp_1")
    }
  }

  @Test func loopbackParsesOnlyTheCallbackPath() {
    let request = "GET /auth/callback?code=abc&state=xyz HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
    #expect(LoopbackCallback.query(fromRequest: request) == ["code": "abc", "state": "xyz"])
    #expect(LoopbackCallback.query(fromRequest: "GET /favicon.ico HTTP/1.1\r\n") == nil)
  }

  @Test func idTokenClaimsAreChecked() throws {
    let claims = #"{"iss":"https://auth.openai.com","aud":["oaiapp_1"],"exp":2000,"nonce":"n1"}"#
    let jwt =
      [#"{"alg":"RS256","kid":"k"}"#, claims].map { base64URL(Data($0.utf8)) }
      .joined(separator: ".") + ".c2ln"
    let token = try IDToken(jwt)
    let expected = IDToken.Expected(
      issuer: "https://auth.openai.com", clientID: "oaiapp_1", nonce: "n1",
      now: Date(timeIntervalSince1970: 1000))
    try token.validateClaims(expected)

    let late = IDToken.Expected(
      issuer: expected.issuer, clientID: "oaiapp_1", nonce: "n1",
      now: Date(timeIntervalSince1970: 3000))
    #expect(throws: AuthError.self) { try token.validateClaims(late) }
  }
}

@Suite struct AccessTokenTests {
  let now = Date(timeIntervalSince1970: 1_000_000)

  func credentials(expiringIn seconds: Double) -> Credentials {
    Credentials(
      clientID: "oaiapp_1", hostID: "urn:uuid:1", email: "me@example.com",
      accessToken: "old", refreshToken: "r1", expiresAt: now.addingTimeInterval(seconds))
  }

  func service(_ store: MemoryCredentialStore, _ transport: ScriptedTransport) -> AuthService {
    let now = now
    return AuthService(store: store, transport: transport, now: { now })
  }

  @Test func freshTokenIsUsedAsIs() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 600))
    let token = try await service(store, ScriptedTransport([])).accessToken()
    #expect(token == "old")
  }

  @Test func expiringTokenIsRefreshedAndRotated() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 60))
    let reply = #"{"access_token":"new","refresh_token":"r2","expires_in":3600}"#
    let token = try await service(store, ScriptedTransport([.lines(status: 200, [reply])]))
      .accessToken()
    #expect(token == "new")
    #expect(store.load()?.refreshToken == "r2")
  }

  @Test func revokedAccessSignsOut() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 60))
    let transport = ScriptedTransport([.lines(status: 400, [#"{"error":"invalid_grant"}"#])])
    await #expect(throws: EngineError.notSignedIn) {
      try await service(store, transport).accessToken()
    }
    #expect(store.load() == nil)
  }

  @Test func withoutCredentialsTheUserIsSignedOut() async throws {
    await #expect(throws: EngineError.notSignedIn) {
      try await service(MemoryCredentialStore(), ScriptedTransport([])).accessToken()
    }
  }
}
