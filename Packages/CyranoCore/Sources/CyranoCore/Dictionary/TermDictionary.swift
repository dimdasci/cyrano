// The «Never change» dictionary: names, terms and slang the model keeps as written. Stored in
// dictionary.json in Application Support. See docs/specs/02-tech-decisions.md M11.

public import Foundation
public import Observation

public struct Term: Hashable, Sendable, Codable, Identifiable {
  public var text: String
  public let added: Date

  /// Terms are unique in any case.
  public var id: String { text.lowercased() }

  enum CodingKeys: String, CodingKey {
    case text = "term"
    case added
  }
}

@MainActor @Observable
public final class TermDictionary {
  /// Oldest first, as added.
  public private(set) var terms: [Term]
  private let file: URL

  /// Reads the file; without one the dictionary is empty. A file that can't be read is kept
  /// next to it as `.bak`, so the next change doesn't overwrite the user's terms.
  public init(file: URL) {
    self.file = file
    terms = Self.read(file)
  }

  /// ~/Library/Application Support/Cyrano/dictionary.json
  public static func standard() -> TermDictionary {
    TermDictionary(
      file: URL.applicationSupportDirectory.appending(path: "Cyrano/dictionary.json"))
  }

  public func contains(_ text: String) -> Bool {
    index(of: text) != nil
  }

  /// Adds a term unless it is blank or already there in any case.
  @discardableResult
  public func add(_ text: String, at date: Date = .now) -> Bool {
    guard insert(text, at: date) else { return false }
    save()
    return true
  }

  @discardableResult
  public func remove(_ text: String) -> Term? {
    guard let index = index(of: text) else { return nil }
    let removed = terms.remove(at: index)
    save()
    return removed
  }

  /// Fails when the new text is blank or another term already has it.
  @discardableResult
  public func rename(_ text: String, to newText: String) -> Bool {
    let newText = newText.trimmed
    guard let index = index(of: text), !newText.isEmpty,
      self.index(of: newText).map({ $0 == index }) ?? true
    else { return false }
    terms[index].text = newText
    save()
    return true
  }

  /// One term per line; blanks and terms already there are skipped. Returns how many were added.
  public func importTerms(from list: String) -> Int {
    let added = list.split(whereSeparator: \.isNewline).count { insert(String($0), at: .now) }
    if added > 0 { save() }
    return added
  }

  /// One term per line, oldest first.
  public var exported: String {
    terms.map { $0.text + "\n" }.joined()
  }

  /// Terms that occur in the text as whole words in any case, in the order they first occur.
  public func found(in text: String) -> [String] {
    terms
      .compactMap { term in text.wordRange(of: term.text).map { (term.text, $0.lowerBound) } }
      .sorted { $0.1 < $1.1 }
      .map(\.0)
  }

  /// The selected words without surrounding spaces, punctuation and quotes; nil for a selection
  /// across lines or of punctuation only.
  nonisolated public static func term(fromSelection selection: String) -> String? {
    let edges = CharacterSet.whitespacesAndNewlines.union(
      CharacterSet(charactersIn: ".,;:!?\"'“”‘’«»()[]{}"))
    let text = selection.trimmingCharacters(in: edges)
    guard !text.isEmpty, !text.contains(where: \.isNewline) else { return nil }
    return text
  }

  private func index(of text: String) -> Int? {
    let id = text.trimmed.lowercased()
    return terms.firstIndex { $0.id == id }
  }

  private func insert(_ text: String, at date: Date) -> Bool {
    let text = text.trimmed
    guard !text.isEmpty, index(of: text) == nil else { return false }
    terms.append(Term(text: text, added: date))
    return true
  }

  private func save() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
    try? FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    // A failed write keeps the terms in memory for this run; the next change writes again.
    try? encoder.encode(terms).write(to: file, options: .atomic)
  }

  private static func read(_ file: URL) -> [Term] {
    guard let data = try? Data(contentsOf: file) else { return [] }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let terms = try? decoder.decode([Term].self, from: data) { return terms }
    let backup = file.appendingPathExtension("bak")
    try? FileManager.default.removeItem(at: backup)
    try? FileManager.default.moveItem(at: file, to: backup)
    return []
  }
}

extension Change {
  /// The replaced words Never Change can keep, without punctuation around them. Adjacent edits
  /// are merged ("kibana, take" → "Kibana. Take"), so each old word the new text doesn't have as
  /// it is counts on its own; inserted words give none.
  public var terms: [String] {
    let kept = Set(new.split(whereSeparator: \.isWhitespace).compactMap(Self.term))
    var terms: [String] = []
    for term in old.split(whereSeparator: \.isWhitespace).compactMap(Self.term)
    where !kept.contains(term) && !terms.contains(term) {
      terms.append(term)
    }
    return terms
  }

  private static func term(_ word: Substring) -> String? {
    TermDictionary.term(fromSelection: String(word))
  }
}

extension String {
  /// The first occurrence of the term, in any case, with no letter or digit right before or after.
  fileprivate func wordRange(of term: String) -> Range<Index>? {
    var start = startIndex
    while let range = range(of: term, options: .caseInsensitive, range: start..<endIndex) {
      let before = range.lowerBound > startIndex ? self[index(before: range.lowerBound)] : nil
      let after = range.upperBound < endIndex ? self[range.upperBound] : nil
      if !(before?.isWordCharacter ?? false), !(after?.isWordCharacter ?? false) { return range }
      start = index(after: range.lowerBound)
    }
    return nil
  }
}

extension Character {
  fileprivate var isWordCharacter: Bool { isLetter || isNumber }
}
