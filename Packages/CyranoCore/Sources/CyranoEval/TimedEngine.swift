// Times every call of one case, so the report can tell Explain from Fix: the session makes the
// calls of a step one after another, Fix first, then Explain if the version has changes.

import CyranoCore
import Foundation
import Synchronization

final class TimedEngine: CorrectionEngine {
  struct Call {
    let duration: Duration
    let tokens: Int
  }

  private let base: any CorrectionEngine
  private let finished = Mutex<[Call]>([])

  init(_ base: any CorrectionEngine) {
    self.base = base
  }

  /// Completed calls, in the order they were made.
  var calls: [Call] { finished.withLock { $0 } }

  func respond(_ call: ModelCall) -> AsyncThrowingStream<ResponseUpdate, any Error> {
    let updates = base.respond(call)
    return AsyncThrowingStream { continuation in
      let task = Task {
        let start = ContinuousClock.now
        do {
          for try await update in updates {
            if case .completed(_, let tokens) = update {
              let call = Call(duration: .now - start, tokens: tokens)
              finished.withLock { $0.append(call) }
            }
            continuation.yield(update)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

extension Duration {
  /// "7.7 s" in any locale, so reports read the same everywhere.
  var inSeconds: String { String(format: "%.1f s", Double(attoseconds) / 1e18) }
}
