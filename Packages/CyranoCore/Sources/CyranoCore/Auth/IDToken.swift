// ID token checks: RS256 signature by JWKS, iss, aud, exp, nonce. See docs/specs/02 A4.

import Foundation
import Security

struct IDToken {
  struct Header: Decodable {
    let alg: String
    let kid: String?
  }

  struct Claims: Decodable {
    let iss: String
    let aud: Audience
    let exp: Double
    let nonce: String?
    let email: String?
  }

  /// `aud` is either one string or a list.
  struct Audience: Decodable {
    let values: [String]

    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let single = try? container.decode(String.self) {
        values = [single]
      } else {
        values = try container.decode([String].self)
      }
    }
  }

  let header: Header
  let claims: Claims
  let signedPart: Data
  let signature: Data

  init(_ jwt: String) throws {
    let parts = jwt.split(separator: ".")
    guard parts.count == 3,
      let header = base64URLDecode(parts[0]), let claims = base64URLDecode(parts[1]),
      let signature = base64URLDecode(parts[2])
    else { throw AuthError.invalidResponse("malformed id_token") }
    self.header = try JSONDecoder().decode(Header.self, from: header)
    self.claims = try JSONDecoder().decode(Claims.self, from: claims)
    self.signedPart = Data("\(parts[0]).\(parts[1])".utf8)
    self.signature = signature
  }

  struct Expected {
    let issuer: String
    let clientID: String
    let nonce: String
    let now: Date
  }

  func validateClaims(_ expected: Expected) throws {
    guard header.alg == "RS256" else { throw AuthError.invalidResponse("alg \(header.alg)") }
    guard claims.iss == expected.issuer else { throw AuthError.invalidResponse("iss") }
    guard claims.aud.values.contains(expected.clientID) else {
      throw AuthError.invalidResponse("aud")
    }
    guard claims.exp > expected.now.timeIntervalSince1970 else {
      throw AuthError.invalidResponse("id_token expired")
    }
    guard claims.nonce == expected.nonce else { throw AuthError.invalidResponse("nonce") }
  }

  func verifySignature(modulus: Data, exponent: Data) throws {
    let key = try rsaPublicKey(modulus: modulus, exponent: exponent)
    let valid = SecKeyVerifySignature(
      key, .rsaSignatureMessagePKCS1v15SHA256, signedPart as CFData, signature as CFData, nil)
    guard valid else { throw AuthError.invalidResponse("id_token signature") }
  }
}

/// Builds a SecKey from a JWK modulus and exponent (PKCS#1 RSAPublicKey DER).
func rsaPublicKey(modulus: Data, exponent: Data) throws -> SecKey {
  let body = derInteger(modulus) + derInteger(exponent)
  let der = Data([0x30]) + derLength(body.count) + body
  let attributes: [CFString: Any] = [
    kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic,
  ]
  guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil) else {
    throw AuthError.invalidResponse("bad RSA key")
  }
  return key
}

private func derLength(_ length: Int) -> Data {
  guard length >= 128 else { return Data([UInt8(length)]) }
  var bytes: [UInt8] = []
  var rest = length
  while rest > 0 {
    bytes.insert(UInt8(rest & 0xff), at: 0)
    rest >>= 8
  }
  return Data([0x80 | UInt8(bytes.count)] + bytes)
}

private func derInteger(_ data: Data) -> Data {
  var bytes = Array(data.drop { $0 == 0 })
  if bytes.isEmpty || bytes[0] & 0x80 != 0 { bytes.insert(0, at: 0) }
  return Data([0x02]) + derLength(bytes.count) + Data(bytes)
}
