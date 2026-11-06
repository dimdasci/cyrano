// Built-in prompt templates. Mirrors docs/specs/04-prompts.md §4; change both together. Fix is in
// FixPrompts.swift.

enum Prompts {
  static let explain = """
    You explain corrections to the author of the text.
    For each numbered change, write one short reason in English, at most 12 words.
    Name the rule when there is one, for example: subject-verb agreement, article, preposition, \
    tense, spelling.
    Use category "style" only when the original was correct and the change is a matter of taste.
    """

  static func explainInput(old: String, diff: TextDiff) -> String {
    let changes = diff.changes.map { change in
      "\(change.id). \"\(change.words[0])\" → \"\(change.words[1])\""
    }
    return (["Original: \(old)", "Corrected: \(diff.newText)", "Changes:"] + changes)
      .joined(separator: "\n")
  }

  /// Who the draft is for, what about and in which language, from a screenshot (04 §4.5).
  static let readContext = """
    The image is a screenshot of the app window where the user is writing. TEXT is the user's \
    draft, typed in the window's input field; the screen shows it too (the input field, a \
    "Draft" preview).
    Describe the conversation the draft belongs to, so a proofreader can choose the language, \
    tone and words. The draft only shows which conversation it is: describe the conversation, \
    not the draft. Use only what is visible: set a field you can't tell to null. Do not guess.
    Write every field in English, whatever the language of the conversation; keep names, job \
    titles and terms as on screen.
    with: who the user writes to, by the names shown on screen; a job title only if it is \
    written (signature, profile). With many recipients in To and Cc, name the person the draft \
    answers and say how many others there are. In a channel or group, name only the person the \
    draft answers: the members are not recipients. DO NOT say how they relate to the user.
    language: the language of the conversation in English, for example "Spanish". Not the \
    language of the draft.
    format: the app and the kind of exchange (email thread, new email, forwarded email, 1:1 \
    chat, channel thread, ticket), and whether the draft replies, follows up on the user's own \
    earlier message, or starts a new topic. Forwarding an email is not a new topic. A channel \
    or group name in the header means a channel or group, not a 1:1 chat.
    about: the topic of the conversation, from the messages, subject or title on screen, in one \
    short sentence of your own words, without amounts, numbers or IDs. DO NOT say what the \
    draft says or does: a fact, name or term found only in the draft stays out. null if the \
    draft starts a new topic: the earlier messages are another conversation. null if the topic \
    is unclear. In a forwarded email, the forwarded message is the topic.
    style: how people write there, in a few words, judged by the messages on screen, not by \
    the draft: short messages or long emails, technical terms, emoji.
    formality: formal, neutral or informal.
    One chat holds many conversations. If the last message is recent and from the other \
    person, the draft likely answers it. After a pause (a date separator, the user's own \
    messages last), a draft about something else starts a new topic: leave the old messages \
    out of about. If the draft refers to the user's own unanswered message, it is a follow-up: \
    about says what that message was about.
    When only part of a conversation is visible, rely on the To field and the subject of the \
    reply, the sender and their signature, the thread or channel title.
    DO NOT copy messages or sentences from the screen. DO NOT describe the draft, the app's \
    interface or other conversations (lists, previews, notifications).
    If nothing on screen relates to the draft, set every field to null.
    """

  static func contextInput(_ text: String) -> String { "TEXT:\n" + quoted(text) }

  private static func quoted(_ text: String) -> String { "\"\"\"\n\(text)\n\"\"\"" }

  /// Strips wrapping quotes the model sometimes adds when the original had none.
  static func cleanOutput(_ output: String, original: String) -> String {
    var text = output.trimmed
    for quote in ["\"\"\"", "\""]
    where text.hasPrefix(quote) && text.hasSuffix(quote) && text.count > 2 * quote.count
      && !original.hasPrefix(quote)
    {
      text = String(text.dropFirst(quote.count).dropLast(quote.count)).trimmed
    }
    return text
  }
}
