import Foundation
import Synchronization
import Testing

@testable import CyranoCore

/// Answers every call with one fixed output and records the calls.
final class FixedEngine: CorrectionEngine {
  private let output: String
  private let recorded = Mutex<[ModelCall]>([])

  init(output: String) { self.output = output }

  var calls: [ModelCall] { recorded.withLock { $0 } }

  func respond(_ call: ModelCall) -> AsyncThrowingStream<ResponseUpdate, any Error> {
    recorded.withLock { $0.append(call) }
    return AsyncThrowingStream { [output] continuation in
      continuation.yield(.delta(output))
      continuation.yield(.completed(text: output, tokens: 5))
      continuation.finish()
    }
  }
}

@Suite struct ScreenReadingTests {
  let screenshot = Data([0x89, 0x50, 0x4E, 0x47])

  @Test func readsTheDraftFromTheScreenshot() async throws {
    let engine = FixedEngine(output: "  Hi Anna,\nI has a question.\n")
    let text = try await ScreenReading.draft(in: screenshot, engine: engine)
    #expect(text == "Hi Anna,\nI has a question.")
    #expect(engine.calls.first?.input.first?.images == [screenshot])
  }

  @Test func noDraftOnScreenGivesNil() async throws {
    let text = try await ScreenReading.draft(in: screenshot, engine: FixedEngine(output: " \n"))
    #expect(text == nil)
  }

  @Test func imagesGoAsDataURLs() throws {
    let call = ModelCall(
      instructions: "Read.", input: [ChatMessage(.user, "Screenshot:", images: [screenshot])])
    let data = try JSONEncoder().encode(ResponsesRequest.body(model: .sol, call: call))
    let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let input = try #require(body["input"] as? [[String: Any]])
    let content = try #require(input.first?["content"] as? [[String: Any]])
    #expect(content.map { $0["type"] as? String } == ["input_text", "input_image"])
    #expect(content.last?["image_url"] as? String == "data:image/png;base64,iVBORw==")
  }
}
