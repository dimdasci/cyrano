import Testing

@testable import CyranoCore

/// Fix replies with JSON by a schema: the kind, then the text (04 §4.3).
@Suite struct FixReplyTests {
  @Test func aDialogReplyIsAVersionOrAnAnswer() {
    let version = FixReply<DialogKind>(output: #"{"kind":"version","text":"I have a cat."}"#)
    let answer = FixReply<DialogKind>(output: #"{"kind":"answer","text":"Yes."}"#)
    #expect(version == FixReply(kind: .version, text: "I have a cat."))
    #expect(answer == FixReply(kind: .answer, text: "Yes."))
  }

  /// A text that asks a question is still a text to correct: the check has no answer kind.
  @Test func aCheckReplyCanOnlyBeAVersion() {
    let answer = FixReply<CheckKind>(output: #"{"kind":"answer","text":"Sure, I will."}"#)
    let kinds: [JSONValue] = CheckKind.allCases.map { .string($0.rawValue) }
    #expect(answer == nil)
    #expect(kinds == ["version"])
  }

  /// The model fills the fields in order, so the kind comes before the text.
  @Test func theSchemaListsTheAllowedKindsBeforeTheText() {
    let schema = String(decoding: FixReply<DialogKind>.schema.json, as: UTF8.self)
    #expect(
      schema
        == #"{"type":"object","additionalProperties":false,"required":["kind","text"],"#
        + #""properties":{"kind":{"type":"string","enum":["version","answer"]},"#
        + #""text":{"type":"string"}}}"#)
  }

  @Test func outputOffTheSchemaIsNoReply() {
    #expect(FixReply<DialogKind>(output: "I have a cat.") == nil)
    #expect(FixReply<DialogKind>(output: #"{"kind":"note","text":"x"}"#) == nil)
  }
}

/// The reply streams as JSON; the panel shows its text as it arrives (04 §4.3).
@Suite struct PartialReplyTests {
  func read(_ deltas: [String]) -> PartialReply {
    var reply = PartialReply()
    for delta in deltas { reply.append(delta) }
    return reply
  }

  @Test func theKindIsKnownOnceItsStringCloses() {
    let open = read([#"{"kind":"ver"#])
    let closed = read([#"{"kind":"ver"#, #"sion","te"#])
    #expect(open.kind == nil)
    #expect(closed.kind == "version")
    #expect(closed.text == "")
  }

  @Test func theTextGrowsWithEachDelta() {
    let reply = read([#"{"kind":"answer","text":"Yes, it"#, " is polite."])
    #expect(reply.kind == "answer")
    #expect(reply.text == "Yes, it is polite.")
  }

  @Test func escapesAreDecodedEvenWhenSplitAcrossDeltas() {
    let reply = read([
      #"{"kind": "version", "text": "Line one.\"#, #"nShe said \"hi\" \\ o"#, #"k é\u"#,
      #"D83D\uDE00"}"#,
    ])
    #expect(reply.text == "Line one.\nShe said \"hi\" \\ ok é😀")
  }

  @Test func theWholeReplyReadsLikeTheDecodedOne() {
    let output = #"{"kind":"version","text":"Tab\there, \/slash, \"quote\"."}"#
    let streamed = read(output.map(String.init))
    let decoded = FixReply<DialogKind>(output: output)
    #expect(streamed.text == decoded?.text)
  }
}
