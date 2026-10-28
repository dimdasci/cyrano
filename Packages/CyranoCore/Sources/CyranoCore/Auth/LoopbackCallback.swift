// One-shot HTTP listener for the OAuth redirect on 127.0.0.1. See docs/specs/02 A2.

import Foundation
import Network
import Synchronization

enum LoopbackCallback {
  /// Query parameters of `GET /auth/callback?…` from the first line of an HTTP request.
  static func query(fromRequest request: String) -> [String: String]? {
    let firstLine = request.components(separatedBy: "\r\n").first ?? ""
    let parts = firstLine.split(separator: " ")
    guard parts.count >= 2, parts[0] == "GET",
      let components = URLComponents(string: String(parts[1])),
      components.path == "/auth/callback"
    else { return nil }
    var query: [String: String] = [:]
    for item in components.queryItems ?? [] { query[item.name] = item.value ?? "" }
    return query
  }

  static func response(found: Bool) -> Data {
    let body =
      found
      ? "<html><body style='font-family:system-ui'>Signed in. You can close this tab "
        + "and return to Cyrano.</body></html>"
      : "Not found"
    let status = found ? "200 OK" : "404 Not Found"
    let head =
      "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n"
      + "Content-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n"
    return Data((head + body).utf8)
  }

  /// Listens until the callback arrives. `onReady` runs once the port is open.
  static func receive(onReady: @escaping @Sendable () -> Void) async throws -> [String: String] {
    let parameters = NWParameters.tcp
    guard let port = NWEndpoint.Port(rawValue: OAuth.port) else { throw AuthError.network }
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
    let listener = try NWListener(using: parameters)
    let queue = DispatchQueue(label: "cyrano.loopback")
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        let result = OnceResult(continuation)
        listener.newConnectionHandler = { connection in
          handle(connection, queue: queue) { query in
            listener.cancel()
            result.resume(.success(query))
          }
        }
        listener.stateUpdateHandler = { state in
          switch state {
          case .ready: onReady()
          case .failed: result.resume(.failure(AuthError.network))
          case .cancelled: result.resume(.failure(AuthError.cancelled))
          default: break
          }
        }
        listener.start(queue: queue)
      }
    } onCancel: {
      listener.cancel()
    }
  }

  private static func handle(
    _ connection: NWConnection, queue: DispatchQueue,
    found: @escaping @Sendable ([String: String]) -> Void
  ) {
    connection.start(queue: queue)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, _ in
      let request = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
      let query = self.query(fromRequest: request)
      connection.send(
        content: response(found: query != nil),
        completion: .contentProcessed { _ in connection.cancel() })
      if let query { found(query) }
    }
  }
}

/// Resumes a continuation at most once, from whichever handler gets there first.
private final class OnceResult: Sendable {
  private let continuation: Mutex<CheckedContinuation<[String: String], any Error>?>

  init(_ continuation: CheckedContinuation<[String: String], any Error>) {
    self.continuation = Mutex(continuation)
  }

  func resume(_ result: Result<[String: String], any Error>) {
    continuation.withLock { pending in
      pending?.resume(with: result)
      pending = nil
    }
  }
}
