// Sign in with ChatGPT, self-serve flow for local apps.
// See docs/specs/02-tech-decisions.md A1–A3 and docs/research/openai-sign-in-with-chatgpt.md.

import CryptoKit
import Foundation

enum OAuth {
  static let issuer = "https://auth.openai.com"
  static let resource = "https://api.openai.com/v1"
  static let port: UInt16 = 1457
  static let redirectURI = "http://127.0.0.1:1457/auth/callback"
  static let scopes =
    "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
  static let planScope = "chatgpt.tokens.use.direct"
  static let dynamicClient = "dynamic_agent_client"
  static let appName = "Cyrano"

  static func url(_ path: String) throws -> URL {
    guard let url = URL(string: issuer + path) else { throw AuthError.invalidResponse(path) }
    return url
  }
}

public enum AuthError: Error, Hashable, Sendable {
  case cancelled
  case planNotAllowed
  case network
  case invalidResponse(String)
}

/// PKCE (S256), state and nonce for one authorization attempt.
struct AuthorizationAttempt {
  let verifier: String
  let state: String
  let nonce: String

  init(
    verifier: String = randomToken(), state: String = randomToken(16),
    nonce: String = randomToken(16)
  ) {
    self.verifier = verifier
    self.state = state
    self.nonce = nonce
  }

  var challenge: String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }

  /// The browser URL. `known` is the account from a previous sign-in, if any.
  func authorizeURL(clientID: String, hostID: String, email: String?) throws -> URL {
    var components = URLComponents(string: OAuth.issuer + "/api/accounts/authorize")
    var items = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "ext_agent_host_id", value: hostID),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "redirect_uri", value: OAuth.redirectURI),
      URLQueryItem(name: "resource", value: OAuth.resource),
      URLQueryItem(name: "scope", value: OAuth.scopes),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "nonce", value: nonce),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
    ]
    if clientID == OAuth.dynamicClient {
      items.append(URLQueryItem(name: "agent_name_hint", value: OAuth.appName))
    }
    if let email { items.append(URLQueryItem(name: "login_hint", value: email)) }
    components?.queryItems = items
    guard let url = components?.url else { throw AuthError.invalidResponse("authorize URL") }
    return url
  }

  /// Checks the loopback callback and returns the code and the issued client ID.
  func accept(_ query: [String: String], requestedClientID: String) throws -> (
    code: String, clientID: String
  ) {
    guard query["state"] == state else { throw AuthError.invalidResponse("state mismatch") }
    if query["error"] == "access_denied" { throw AuthError.cancelled }
    if let error = query["error"] { throw AuthError.invalidResponse(error) }
    guard let code = query["code"] else { throw AuthError.invalidResponse("no code") }
    let issued = query["client_id"] ?? requestedClientID
    guard issued != OAuth.dynamicClient else { throw AuthError.invalidResponse("no client_id") }
    let isReauthorization = requestedClientID != OAuth.dynamicClient
    if isReauthorization, issued != requestedClientID {
      throw AuthError.invalidResponse("unexpected client_id")
    }
    return (code, issued)
  }
}

func base64URL(_ data: Data) -> String {
  data.base64EncodedString()
    .replacingOccurrences(of: "+", with: "-")
    .replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
}

func base64URLDecode(_ string: some StringProtocol) -> Data? {
  var text = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(
    of: "_", with: "/")
  while !text.count.isMultiple(of: 4) { text += "=" }
  return Data(base64Encoded: text)
}

func randomToken(_ bytes: Int = 32) -> String {
  base64URL(Data((0..<bytes).map { _ in UInt8.random(in: 0...255) }))
}
