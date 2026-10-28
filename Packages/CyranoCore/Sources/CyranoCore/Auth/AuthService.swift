// Sign in, token refresh and sign out. See docs/specs/02-tech-decisions.md A1–A7.

public import Foundation

public struct Account: Hashable, Sendable {
  public let email: String?
}

public actor AuthService {
  private let store: any CredentialStore
  private let transport: any HTTPTransport
  private let now: @Sendable () -> Date
  private var refreshing: Task<Credentials, any Error>?

  public init(transport: any HTTPTransport = URLSessionTransport()) {
    self.init(
      store: KeychainCredentialStore(service: "app.cyrano.chatgpt"), transport: transport,
      now: { Date() })
  }

  init(
    store: any CredentialStore, transport: any HTTPTransport, now: @escaping @Sendable () -> Date
  ) {
    self.store = store
    self.transport = transport
    self.now = now
  }

  public var account: Account? { store.load().map { Account(email: $0.email) } }

  /// Opens the browser and waits up to five minutes for the redirect.
  public func signIn(openBrowser: @escaping @Sendable (URL) -> Void) async throws -> Account {
    let existing = store.load()
    let clientID = existing?.clientID ?? OAuth.dynamicClient
    let hostID = existing?.hostID ?? "urn:uuid:\(UUID().uuidString.lowercased())"
    let attempt = AuthorizationAttempt()
    let url = try attempt.authorizeURL(clientID: clientID, hostID: hostID, email: existing?.email)
    let query = try await withTimeout(seconds: 300) {
      try await LoopbackCallback.receive { openBrowser(url) }
    }
    let (code, issued) = try attempt.accept(query, requestedClientID: clientID)
    let token = try await requestToken([
      "grant_type": "authorization_code", "client_id": issued, "code": code,
      "code_verifier": attempt.verifier, "redirect_uri": OAuth.redirectURI,
      "resource": OAuth.resource,
    ])
    let scopes = (token.scope ?? query["scope"] ?? "").split { $0 == " " || $0 == "+" }
    guard scopes.contains(Substring(OAuth.planScope)) else { throw AuthError.planNotAllowed }
    guard let idToken = token.idToken, let refreshToken = token.refreshToken else {
      throw AuthError.invalidResponse("token response is missing tokens")
    }
    let email = try await validate(idToken, clientID: issued, nonce: attempt.nonce)
    let credentials = Credentials(
      clientID: issued, hostID: hostID, email: email, accessToken: token.accessToken,
      refreshToken: refreshToken, expiresAt: now().addingTimeInterval(token.expiresIn ?? 3600))
    try store.save(credentials)
    return Account(email: email)
  }

  /// A valid access token, refreshed two minutes before it expires.
  public func accessToken() async throws -> String {
    guard let credentials = store.load() else { throw EngineError.notSignedIn }
    if credentials.expiresAt > now().addingTimeInterval(120) { return credentials.accessToken }
    if let refreshing { return try await refreshing.value.accessToken }
    let task = Task { try await refresh(credentials) }
    refreshing = task
    defer { refreshing = nil }
    return try await task.value.accessToken
  }

  /// Revokes the refresh token when possible and forgets the credentials.
  public func signOut() async {
    guard let credentials = store.load() else { return }
    store.delete()
    guard let configuration = try? await discovery(),
      let endpoint = configuration.revocationEndpoint.flatMap(URL.init(string:))
    else { return }
    _ = try? await transport.data(
      for: formRequest(
        endpoint,
        ["token": credentials.refreshToken, "client_id": credentials.clientID]))
  }

  private func refresh(_ credentials: Credentials) async throws -> Credentials {
    let token: TokenResponse
    do {
      token = try await requestToken([
        "grant_type": "refresh_token", "client_id": credentials.clientID,
        "refresh_token": credentials.refreshToken, "resource": OAuth.resource,
      ])
    } catch is TokenRejected {
      store.delete()
      throw EngineError.notSignedIn
    } catch {
      throw EngineError.network
    }
    var updated = credentials
    updated.accessToken = token.accessToken
    updated.refreshToken = token.refreshToken ?? credentials.refreshToken
    updated.expiresAt = now().addingTimeInterval(token.expiresIn ?? 3600)
    try store.save(updated)
    return updated
  }

  private func requestToken(_ fields: [String: String]) async throws -> TokenResponse {
    let request = formRequest(try OAuth.url("/api/accounts/oauth/token"), fields)
    let (status, body) = try await networkData(request)
    if status == 400 || status == 401 { throw TokenRejected() }
    guard status == 200 else {
      throw AuthError.invalidResponse("token \(status): \(String(decoding: body, as: UTF8.self))")
    }
    return try JSONDecoder().decode(TokenResponse.self, from: body)
  }

  /// Checks the ID token and returns the email it carries.
  private func validate(_ jwt: String, clientID: String, nonce: String) async throws -> String? {
    let token = try IDToken(jwt)
    let configuration = try await discovery()
    try token.validateClaims(
      .init(issuer: configuration.issuer, clientID: clientID, nonce: nonce, now: now()))
    guard let jwksURL = URL(string: configuration.jwksURI) else {
      throw AuthError.invalidResponse("jwks_uri")
    }
    let keys = try await getJSON(KeySet.self, from: jwksURL).keys
    guard let key = keys.first(where: { $0.kid == token.header.kid }),
      let modulus = base64URLDecode(key.n), let exponent = base64URLDecode(key.e)
    else { throw AuthError.invalidResponse("signing key not found") }
    try token.verifySignature(modulus: modulus, exponent: exponent)
    return token.claims.email
  }

  private func discovery() async throws -> Discovery {
    try await getJSON(Discovery.self, from: try OAuth.url("/.well-known/openid-configuration"))
  }

  private func getJSON<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
    let (status, body) = try await networkData(URLRequest(url: url))
    guard status == 200 else { throw AuthError.invalidResponse("GET \(url.path) \(status)") }
    return try JSONDecoder().decode(type, from: body)
  }

  private func networkData(_ request: URLRequest) async throws -> (Int, Data) {
    do {
      return try await transport.data(for: request)
    } catch is URLError {
      throw AuthError.network
    }
  }
}

private func formRequest(_ url: URL, _ fields: [String: String]) -> URLRequest {
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
  var components = URLComponents()
  components.queryItems = fields.sorted { $0.key < $1.key }.map(URLQueryItem.init)
  request.httpBody = components.percentEncodedQuery?
    .replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
  return request
}

private func withTimeout<T: Sendable>(
  seconds: Int, _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  try await withThrowingTaskGroup(of: T.self) { group in
    group.addTask { try await operation() }
    group.addTask {
      try await Task.sleep(for: .seconds(seconds))
      throw AuthError.network
    }
    defer { group.cancelAll() }
    guard let result = try await group.next() else { throw AuthError.cancelled }
    return result
  }
}

/// The token endpoint refused the grant: the refresh token was revoked or has expired.
private struct TokenRejected: Error {}

private struct TokenResponse: Decodable {
  let accessToken: String
  let refreshToken: String?
  let idToken: String?
  let expiresIn: Double?
  let scope: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case idToken = "id_token"
    case expiresIn = "expires_in"
    case scope
  }
}

private struct Discovery: Decodable {
  let issuer: String
  let jwksURI: String
  let revocationEndpoint: String?

  enum CodingKeys: String, CodingKey {
    case issuer
    case jwksURI = "jwks_uri"
    case revocationEndpoint = "revocation_endpoint"
  }
}

private struct KeySet: Decodable {
  struct Key: Decodable {
    let kid: String?
    let n: String
    let e: String
  }
  let keys: [Key]
}
