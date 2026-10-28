// Tokens live only in the Keychain. See docs/specs/02-tech-decisions.md A5, S1.

import Foundation
import Security

struct Credentials: Codable, Hashable, Sendable {
  let clientID: String
  let hostID: String
  let email: String?
  var accessToken: String
  var refreshToken: String
  var expiresAt: Date
}

protocol CredentialStore: Sendable {
  func load() -> Credentials?
  func save(_ credentials: Credentials) throws
  func delete()
}

struct KeychainCredentialStore: CredentialStore {
  let service: String

  private var query: [CFString: Any] {
    [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: "chatgpt"]
  }

  func load() -> Credentials? {
    var request = query
    request[kSecReturnData] = true
    var result: CFTypeRef?
    guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return try? JSONDecoder().decode(Credentials.self, from: data)
  }

  func save(_ credentials: Credentials) throws {
    delete()
    var item = query
    item[kSecValueData] = try JSONEncoder().encode(credentials)
    item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(item as CFDictionary, nil)
    guard status == errSecSuccess else { throw AuthError.invalidResponse("Keychain \(status)") }
  }

  func delete() {
    SecItemDelete(query as CFDictionary)
  }
}
