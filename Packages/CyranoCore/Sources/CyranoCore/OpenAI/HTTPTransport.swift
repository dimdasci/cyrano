public import Foundation

/// The network, behind a protocol so tests can script responses.
public protocol HTTPTransport: Sendable {
  func data(for request: URLRequest) async throws -> (status: Int, body: Data)
  func stream(for request: URLRequest) async throws -> HTTPStream
}

public struct HTTPStream: Sendable {
  public let status: Int
  public let lines: AsyncThrowingStream<String, any Error>

  public init(status: Int, lines: AsyncThrowingStream<String, any Error>) {
    self.status = status
    self.lines = lines
  }
}

public struct URLSessionTransport: HTTPTransport {
  public init() {}

  public func data(for request: URLRequest) async throws -> (status: Int, body: Data) {
    let (data, response) = try await URLSession.shared.data(for: request)
    return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
  }

  public func stream(for request: URLRequest) async throws -> HTTPStream {
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    let lines = AsyncThrowingStream<String, any Error> { continuation in
      let task = Task {
        do {
          for try await line in bytes.lines { continuation.yield(line) }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
    return HTTPStream(status: (response as? HTTPURLResponse)?.statusCode ?? 0, lines: lines)
  }
}
