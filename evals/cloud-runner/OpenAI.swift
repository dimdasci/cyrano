// Sign in with ChatGPT (open-source / locally hosted flow) and a minimal Responses API client.
// See docs/research/openai-sign-in-with-chatgpt.md.
import CryptoKit
import Foundation
import Network
import Security

enum OpenAI {
  static let auth = URL(string: "https://auth.openai.com")!
  static let resource = "https://api.openai.com/v1"
  static let port: UInt16 = 1457
  static var redirectURI: String { "http://127.0.0.1:\(port)/auth/callback" }
  static let scopes = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
  static let appName = "Cyrano (prototype)"
}

struct OpenAIError: Error, CustomStringConvertible {
  var description: String
  init(_ d: String) { description = d }
}

// MARK: - Credentials (Keychain)

struct Credentials: Codable {
  var clientID: String
  var hostID: String
  var subject: String
  var email: String?
  var accessToken: String
  var refreshToken: String
  var expiresAt: Date
}

enum Keychain {
  static let service = "grammar-prototype.openai"
  static let account = "credentials"

  static func load() -> Credentials? {
    let q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account, kSecReturnData as String: true,
    ]
    var out: CFTypeRef?
    guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
    return try? JSONDecoder().decode(Credentials.self, from: data)
  }

  static func save(_ c: Credentials) throws {
    let data = try JSONEncoder().encode(c)
    let q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(q as CFDictionary)
    var add = q
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let st = SecItemAdd(add as CFDictionary, nil)
    guard st == errSecSuccess else { throw OpenAIError("Keychain save failed: \(st)") }
  }
}

// MARK: - Helpers

func base64URL(_ d: Data) -> String {
  d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    .replacingOccurrences(of: "=", with: "")
}

func base64URLDecode(_ s: String) -> Data? {
  var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
  while t.count % 4 != 0 { t += "=" }
  return Data(base64Encoded: t)
}

func randomToken(_ bytes: Int = 32) -> String {
  base64URL(Data((0..<bytes).map { _ in UInt8.random(in: 0...255) }))
}

func formPost(_ url: URL, _ fields: [String: String]) async throws -> [String: Any] {
  var req = URLRequest(url: url)
  req.httpMethod = "POST"
  req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
  var c = URLComponents()
  c.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
  req.httpBody = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
  let (data, resp) = try await URLSession.shared.data(for: req)
  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
  guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
    throw OpenAIError("\(url.path) → \((resp as? HTTPURLResponse)?.statusCode ?? 0): \(String(data: data, encoding: .utf8) ?? "")")
  }
  return json
}

func getJSON(_ url: URL, bearer: String? = nil) async throws -> [String: Any] {
  var req = URLRequest(url: url)
  if let bearer { req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
  let (data, resp) = try await URLSession.shared.data(for: req)
  guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
    throw OpenAIError("GET \(url.path) → \((resp as? HTTPURLResponse)?.statusCode ?? 0): \(String(data: data, encoding: .utf8) ?? "")")
  }
  return (try JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}

// MARK: - Loopback callback

/// Waits for one GET /auth/callback on 127.0.0.1 and returns its query parameters.
func waitForCallback() async throws -> [String: String] {
  let queue = DispatchQueue(label: "loopback")
  let params = NWParameters.tcp
  params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: OpenAI.port)!)
  let listener = try NWListener(using: params)
  return try await withCheckedThrowingContinuation { cont in
    var finished = false
    listener.newConnectionHandler = { conn in
      conn.start(queue: queue)
      conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
        let line = data.flatMap { String(data: $0, encoding: .utf8) }?.components(separatedBy: "\r\n").first ?? ""
        let target = line.split(separator: " ").dropFirst().first.map(String.init) ?? ""
        let comps = URLComponents(string: target)
        let ok = comps?.path == "/auth/callback"
        let body = ok ? "<html><body style='font-family:sans-serif'>Done. You can close this tab.</body></html>" : "Not found"
        let resp = "HTTP/1.1 \(ok ? "200 OK" : "404 Not Found")\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
        guard ok, !finished else { return }
        finished = true
        listener.cancel()
        var q: [String: String] = [:]
        for item in comps?.queryItems ?? [] { q[item.name] = item.value ?? "" }
        cont.resume(returning: q)
      }
    }
    listener.stateUpdateHandler = { state in
      if case .failed(let e) = state, !finished { finished = true; cont.resume(throwing: e) }
    }
    listener.start(queue: queue)
  }
}

// MARK: - ID token

/// Verifies the RS256 signature against OpenAI's JWKS and checks iss, aud, exp and nonce.
func validateIDToken(_ jwt: String, clientID: String, nonce: String) async throws -> [String: Any] {
  let parts = jwt.split(separator: ".").map(String.init)
  guard parts.count == 3, let h = base64URLDecode(parts[0]), let p = base64URLDecode(parts[1]),
    let sig = base64URLDecode(parts[2]),
    let header = try JSONSerialization.jsonObject(with: h) as? [String: Any],
    let claims = try JSONSerialization.jsonObject(with: p) as? [String: Any]
  else { throw OpenAIError("malformed id_token") }
  guard header["alg"] as? String == "RS256" else { throw OpenAIError("unexpected alg \(header["alg"] ?? "")") }

  let config = try await getJSON(OpenAI.auth.appending(path: ".well-known/openid-configuration"))
  guard let jwksURI = (config["jwks_uri"] as? String).flatMap(URL.init(string:)), let issuer = config["issuer"] as? String
  else { throw OpenAIError("bad openid-configuration") }
  let keys = (try await getJSON(jwksURI))["keys"] as? [[String: Any]] ?? []
  guard let jwk = keys.first(where: { $0["kid"] as? String == header["kid"] as? String }),
    let n = (jwk["n"] as? String).flatMap(base64URLDecode), let e = (jwk["e"] as? String).flatMap(base64URLDecode)
  else { throw OpenAIError("signing key not found") }

  let key = try rsaPublicKey(modulus: n, exponent: e)
  let signed = Data("\(parts[0]).\(parts[1])".utf8)
  var err: Unmanaged<CFError>?
  guard SecKeyVerifySignature(key, .rsaSignatureMessagePKCS1v15SHA256, signed as CFData, sig as CFData, &err) else {
    throw OpenAIError("id_token signature invalid")
  }
  let aud = (claims["aud"] as? String).map { [$0] } ?? (claims["aud"] as? [String] ?? [])
  guard claims["iss"] as? String == issuer else { throw OpenAIError("id_token iss mismatch") }
  guard aud.contains(clientID) else { throw OpenAIError("id_token aud mismatch") }
  guard let exp = claims["exp"] as? Double, exp > Date().timeIntervalSince1970 else { throw OpenAIError("id_token expired") }
  guard claims["nonce"] as? String == nonce else { throw OpenAIError("id_token nonce mismatch") }
  return claims
}

/// Builds a SecKey from a JWK modulus and exponent (PKCS#1 RSAPublicKey DER).
func rsaPublicKey(modulus: Data, exponent: Data) throws -> SecKey {
  func length(_ n: Int) -> Data {
    if n < 128 { return Data([UInt8(n)]) }
    var bytes: [UInt8] = []
    var x = n
    while x > 0 { bytes.insert(UInt8(x & 0xff), at: 0); x >>= 8 }
    return Data([0x80 | UInt8(bytes.count)] + bytes)
  }
  func integer(_ d: Data) -> Data {
    var v = [UInt8](d)
    while v.count > 1 && v[0] == 0 { v.removeFirst() }
    if v[0] & 0x80 != 0 { v.insert(0, at: 0) }
    return Data([0x02]) + length(v.count) + Data(v)
  }
  let body = integer(modulus) + integer(exponent)
  let der = Data([0x30]) + length(body.count) + body
  let attrs: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: kSecAttrKeyClassPublic]
  var err: Unmanaged<CFError>?
  guard let key = SecKeyCreateWithData(der as CFData, attrs as CFDictionary, &err) else { throw OpenAIError("bad RSA key") }
  return key
}

// MARK: - Sign in / refresh

func signIn() async throws -> Credentials {
  let existing = Keychain.load()
  let hostID = existing?.hostID ?? "urn:uuid:\(UUID().uuidString.lowercased())"
  let clientID = existing?.clientID ?? "dynamic_agent_client"
  let verifier = randomToken(), state = randomToken(16), nonce = randomToken(16)
  let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))

  var c = URLComponents(url: OpenAI.auth.appending(path: "api/accounts/authorize"), resolvingAgainstBaseURL: false)!
  var items = [
    URLQueryItem(name: "client_id", value: clientID),
    URLQueryItem(name: "ext_agent_host_id", value: hostID),
    URLQueryItem(name: "response_type", value: "code"),
    URLQueryItem(name: "redirect_uri", value: OpenAI.redirectURI),
    URLQueryItem(name: "resource", value: OpenAI.resource),
    URLQueryItem(name: "scope", value: OpenAI.scopes),
    URLQueryItem(name: "state", value: state),
    URLQueryItem(name: "nonce", value: nonce),
    URLQueryItem(name: "code_challenge", value: challenge),
    URLQueryItem(name: "code_challenge_method", value: "S256"),
  ]
  if existing == nil { items.append(URLQueryItem(name: "agent_name_hint", value: OpenAI.appName)) }
  if let email = existing?.email { items.append(URLQueryItem(name: "login_hint", value: email)) }
  c.queryItems = items

  async let callback = waitForCallback()
  try await Task.sleep(for: .milliseconds(300))
  print("Opening the browser to sign in with ChatGPT…")
  let open = Process()
  open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
  open.arguments = [c.url!.absoluteString]
  try open.run()

  let q = try await callback
  guard q["state"] == state else { throw OpenAIError("state mismatch") }
  if let e = q["error"] { throw OpenAIError("authorization failed: \(e) \(q["error_description"] ?? "")") }
  guard let code = q["code"] else { throw OpenAIError("no code in callback") }
  let issued = q["client_id"] ?? clientID
  guard issued != "dynamic_agent_client" else { throw OpenAIError("no issued client_id in callback") }
  if let existing, issued != existing.clientID { throw OpenAIError("unexpected client_id on reauthorization") }

  let token = try await formPost(
    OpenAI.auth.appending(path: "api/accounts/oauth/token"),
    [
      "grant_type": "authorization_code", "client_id": issued, "code": code, "code_verifier": verifier,
      "redirect_uri": OpenAI.redirectURI, "resource": OpenAI.resource,
    ])
  guard let access = token["access_token"] as? String, let refresh = token["refresh_token"] as? String,
    let idToken = token["id_token"] as? String
  else { throw OpenAIError("token response is missing tokens") }
  let granted = (token["scope"] as? String ?? q["scope"] ?? "").split(whereSeparator: { $0 == " " || $0 == "+" })
  guard granted.contains("chatgpt.tokens.use.direct") else { throw OpenAIError("plan usage was not granted") }
  let claims = try await validateIDToken(idToken, clientID: issued, nonce: nonce)

  let creds = Credentials(
    clientID: issued, hostID: hostID, subject: claims["sub"] as? String ?? "", email: claims["email"] as? String,
    accessToken: access, refreshToken: refresh,
    expiresAt: Date().addingTimeInterval(token["expires_in"] as? Double ?? 3600))
  try Keychain.save(creds)
  return creds
}

/// Returns a valid access token, refreshing it (and the rotating refresh token) when it is about to expire.
func accessToken() async throws -> String {
  guard var c = Keychain.load() else { throw OpenAIError("not signed in, run: openai-runner login") }
  if c.expiresAt > Date().addingTimeInterval(120) { return c.accessToken }
  let token = try await formPost(
    OpenAI.auth.appending(path: "api/accounts/oauth/token"),
    ["grant_type": "refresh_token", "client_id": c.clientID, "refresh_token": c.refreshToken, "resource": OpenAI.resource])
  guard let access = token["access_token"] as? String else { throw OpenAIError("refresh failed") }
  c.accessToken = access
  if let r = token["refresh_token"] as? String { c.refreshToken = r }
  c.expiresAt = Date().addingTimeInterval(token["expires_in"] as? Double ?? 3600)
  try Keychain.save(c)
  return access
}

// MARK: - Responses API

func listModels() async throws -> [String] {
  let json = try await getJSON(URL(string: "\(OpenAI.resource)/models")!, bearer: try await accessToken())
  // Plan-usage tokens get {"models": [{"slug": …, "visibility": …}]} rather than the API-key {"data": [{"id": …}]} shape.
  let models = json["models"] as? [[String: Any]] ?? json["data"] as? [[String: Any]] ?? []
  return models.filter { ($0["visibility"] as? String ?? "list") == "list" }.compactMap { ($0["slug"] ?? $0["id"]) as? String }
}

struct ChatMessage {
  var role: String
  var text: String
  /// PNG images sent after the text as input_image data URLs.
  var images: [Data] = []
}

/// One streamed Responses API call. `schema` requests JSON output matching it.
func respond(model: String, instructions: String, input: [ChatMessage], schema: [String: Any]? = nil) async throws -> String {
  var body: [String: Any] = [
    "model": model, "instructions": instructions, "store": false, "stream": true,
    "input": input.map { m in
      ["role": m.role, "content": [["type": m.role == "assistant" ? "output_text" : "input_text", "text": m.text]]
        + m.images.map { ["type": "input_image", "image_url": "data:image/png;base64,\($0.base64EncodedString())"] }]
    },
  ]
  if let effort = ProcessInfo.processInfo.environment["EFFORT"] { body["reasoning"] = ["effort": effort] }
  if let schema { body["text"] = ["format": ["type": "json_schema", "name": "result", "schema": schema, "strict": true]] }

  var req = URLRequest(url: URL(string: "\(OpenAI.resource)/responses")!)
  req.httpMethod = "POST"
  req.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
  req.setValue("application/json", forHTTPHeaderField: "Content-Type")
  req.httpBody = try JSONSerialization.data(withJSONObject: body)

  let (bytes, resp) = try await URLSession.shared.bytes(for: req)
  if (resp as? HTTPURLResponse)?.statusCode != 200 {
    var text = ""
    for try await line in bytes.lines { text += line }
    throw OpenAIError("responses → \((resp as? HTTPURLResponse)?.statusCode ?? 0): \(text)")
  }
  var out = ""
  for try await line in bytes.lines {
    guard line.hasPrefix("data:") else { continue }
    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
    guard let ev = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { continue }
    switch ev["type"] as? String {
    case "response.output_text.delta": out += ev["delta"] as? String ?? ""
    case "response.completed": return out
    case "response.failed", "error":
      let r = ev["response"] as? [String: Any]
      let e = (r?["error"] ?? ev["error"] ?? ev) as Any
      throw OpenAIError("generation failed: \(e)")
    default: break
    }
  }
  throw OpenAIError("stream ended without response.completed")
}
