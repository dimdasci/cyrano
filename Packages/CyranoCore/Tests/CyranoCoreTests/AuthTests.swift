import Foundation
import Security
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

/// Query items of a URL by name.
func query(_ url: URL) -> [String: String] {
  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
  return Dictionary(
    items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
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
    let values = query(url)
    #expect(url.host() == "auth.openai.com")
    #expect(values["agent_name_hint"] == "Cyrano")
    #expect(values["code_challenge_method"] == "S256")
    #expect(values["redirect_uri"] == "http://127.0.0.1:1457/auth/callback")
    #expect(values["scope"]?.contains("chatgpt.tokens.use.direct") == true)
  }

  @Test func signingInAgainNamesTheIssuedClientAndTheAccount() throws {
    let url = try AuthorizationAttempt().authorizeURL(
      clientID: "oaiapp_1", hostID: "urn:uuid:1", email: "me@example.com")
    let values = query(url)
    #expect(values["client_id"] == "oaiapp_1")
    #expect(values["login_hint"] == "me@example.com")
    #expect(values["agent_name_hint"] == nil)
  }

  @Test func callbackGivesCodeAndIssuedClient() throws {
    let attempt = AuthorizationAttempt(state: "s1")
    let accepted = try attempt.accept(
      ["state": "s1", "code": "c1", "client_id": "oaiapp_1"],
      requestedClientID: "dynamic_agent_client")
    #expect(accepted.code == "c1")
    #expect(accepted.clientID == "oaiapp_1")
  }

  @Test func callbackRejectsWrongStateDenialAndClient() {
    let attempt = AuthorizationAttempt(state: "s1")
    #expect(throws: AuthError.self) {
      try attempt.accept(["state": "other", "code": "c"], requestedClientID: "oaiapp_1")
    }
    #expect(throws: AuthError.cancelled) {
      try attempt.accept(["state": "s1", "error": "access_denied"], requestedClientID: "oaiapp_1")
    }
    #expect(throws: AuthError.self) {
      try attempt.accept(
        ["state": "s1", "code": "c", "client_id": "oaiapp_2"], requestedClientID: "oaiapp_1")
    }
    #expect(throws: AuthError.self) {
      try attempt.accept(["state": "s1", "code": "c"], requestedClientID: "dynamic_agent_client")
    }
  }

  @Test func loopbackParsesOnlyTheCallbackPath() {
    let request = "GET /auth/callback?code=abc&state=xyz HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
    #expect(LoopbackCallback.query(fromRequest: request) == ["code": "abc", "state": "xyz"])
    #expect(LoopbackCallback.query(fromRequest: "GET /favicon.ico HTTP/1.1\r\n") == nil)
  }
}

/// ID token checks before the account is saved (A4).
@Suite struct IDTokenTests {
  let claims = #"{"iss":"https://auth.openai.com","aud":["oaiapp_1"],"exp":2000,"nonce":"n1"}"#

  func jwt(_ claims: String, header: String = #"{"alg":"RS256","kid":"k"}"#) -> String {
    [header, claims].map { base64URL(Data($0.utf8)) }.joined(separator: ".") + ".c2ln"
  }

  func expected(
    issuer: String = "https://auth.openai.com", clientID: String = "oaiapp_1",
    nonce: String = "n1", now: Double = 1000
  ) -> IDToken.Expected {
    IDToken.Expected(
      issuer: issuer, clientID: clientID, nonce: nonce, now: Date(timeIntervalSince1970: now))
  }

  @Test func eachClaimMustMatch() throws {
    let token = try IDToken(jwt(claims))
    try token.validateClaims(expected())
    let mismatches = [
      expected(issuer: "https://example.com"), expected(clientID: "oaiapp_2"),
      expected(nonce: "n2"), expected(now: 3000),
    ]
    for mismatch in mismatches {
      #expect(throws: AuthError.self) { try token.validateClaims(mismatch) }
    }
  }

  @Test func onlyRS256IsAccepted() throws {
    let token = try IDToken(jwt(claims, header: #"{"alg":"HS256"}"#))
    #expect(throws: AuthError.self) { try token.validateClaims(expected()) }
  }

  @Test func signatureIsCheckedWithTheKeyFromJWKS() throws {
    let key = try RSATestKey()
    let signed = [#"{"alg":"RS256","kid":"k"}"#, claims].map { base64URL(Data($0.utf8)) }
      .joined(separator: ".")
    let token = try IDToken(signed + "." + base64URL(key.sign(signed)))
    try token.verifySignature(modulus: key.modulus, exponent: key.exponent)

    let forged = try IDToken(jwt(claims))
    #expect(throws: AuthError.self) {
      try forged.verifySignature(modulus: key.modulus, exponent: key.exponent)
    }
  }
}

/// A fresh RSA key, its JWK modulus and exponent, as the JWKS endpoint gives them.
struct RSATestKey {
  let privateKey: SecKey
  let modulus: Data
  let exponent: Data

  init() throws {
    let attributes: [CFString: Any] = [
      kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048,
    ]
    privateKey = try #require(SecKeyCreateRandomKey(attributes as CFDictionary, nil))
    let publicKey = try #require(SecKeyCopyPublicKey(privateKey))
    // PKCS#1 RSAPublicKey: SEQUENCE { INTEGER modulus, INTEGER exponent }.
    let external = try #require(SecKeyCopyExternalRepresentation(publicKey, nil) as Data?)
    var der = DERReader(bytes: Array(external))
    _ = der.header()
    modulus = der.integer()
    exponent = der.integer()
  }

  func sign(_ text: String) throws -> Data {
    let signature = SecKeyCreateSignature(
      privateKey, .rsaSignatureMessagePKCS1v15SHA256, Data(text.utf8) as CFData, nil)
    return try #require(signature as Data?)
  }
}

struct DERReader {
  let bytes: [UInt8]
  var index = 0

  /// Skips a tag and returns the length of its content.
  mutating func header() -> Int {
    index += 1
    var length = Int(bytes[index])
    index += 1
    if length >= 0x80 {
      let count = length - 0x80
      length = bytes[index..<index + count].reduce(0) { $0 << 8 | Int($1) }
      index += count
    }
    return length
  }

  mutating func integer() -> Data {
    let length = header()
    defer { index += length }
    return Data(bytes[index..<index + length])
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

  static let refreshed = #"{"access_token":"new","refresh_token":"r2","expires_in":3600}"#

  @Test func freshTokenIsUsedAsIs() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 600))
    let token = try await service(store, ScriptedTransport([])).accessToken()
    #expect(token == "old")
  }

  @Test func expiringTokenIsRefreshedAndRotated() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 60))
    let transport = ScriptedTransport([.lines(status: 200, [Self.refreshed])])
    let token = try await service(store, transport).accessToken()
    #expect(token == "new")
    #expect(store.load()?.refreshToken == "r2")
  }

  /// The refresh token rotates: a second refresh with the old one would sign the user out.
  @Test func concurrentRequestsRefreshOnce() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 60))
    let transport = ScriptedTransport([.lines(status: 200, [Self.refreshed])])
    let service = service(store, transport)
    async let first = service.accessToken()
    async let second = service.accessToken()
    #expect(try await [first, second] == ["new", "new"])
    #expect(await transport.requests.count == 1)
  }

  @Test func revokedAccessSignsOut() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 60))
    let transport = ScriptedTransport([.lines(status: 400, [#"{"error":"invalid_grant"}"#])])
    await #expect(throws: EngineError.notSignedIn) {
      try await service(store, transport).accessToken()
    }
    #expect(store.load() == nil)
  }

  @Test func offlineRefreshKeepsTheAccount() async throws {
    let store = MemoryCredentialStore(credentials(expiringIn: 60))
    let transport = ScriptedTransport([.failure(.notConnectedToInternet)])
    await #expect(throws: EngineError.network) {
      try await service(store, transport).accessToken()
    }
    #expect(store.load()?.refreshToken == "r1")
  }

  @Test func withoutCredentialsTheUserIsSignedOut() async throws {
    await #expect(throws: EngineError.notSignedIn) {
      try await service(MemoryCredentialStore(), ScriptedTransport([])).accessToken()
    }
  }

  @Test func signOutForgetsTheAccountEvenOffline() async {
    let store = MemoryCredentialStore(credentials(expiringIn: 600))
    let service = service(store, ScriptedTransport([.failure(.notConnectedToInternet)]))
    await service.signOut()
    #expect(store.load() == nil)
    #expect(await service.account == nil)
  }
}
