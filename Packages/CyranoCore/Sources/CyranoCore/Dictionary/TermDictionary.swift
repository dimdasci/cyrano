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
    terms = JSONFile.read([Term].self, from: file) ?? []
  }

  /// ~/Library/Application Support/Cyrano/dictionary.json
  public static func standard() -> TermDictionary {
    TermDictionary(file: JSONFile.standard("dictionary.json"))
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

  /// Terms the text seems to misspell: words a letter off, two for terms of nine letters and
  /// more, in the order of the text. A term found as written, in any case, or shorter than five
  /// letters is no hint: "quick" is a word of its own, and "k8s" can't be told from "k9s".
  public func misspelled(in text: String) -> [String] {
    let words = text.lowercasedWords
    return terms.compactMap { term -> (String, Int)? in
      let termWords = term.text.lowercasedWords.map(\.word)
      let allowed = Self.allowedEdits(termWords.joined().count)
      guard allowed > 0, words.count >= termWords.count, text.wordRange(of: term.text) == nil
      else { return nil }
      let target = termWords.joined(separator: " ")
      let start = (0...(words.count - termWords.count)).first { start in
        let candidate = words[start..<start + termWords.count].map(\.word)
        return (1...allowed).contains(editDistance(candidate.joined(separator: " "), target))
      }
      return start.map { (term.text, words[$0].offset) }
    }
    .sorted { $0.1 < $1.1 }
    .map(\.0)
  }

  private static func allowedEdits(_ letters: Int) -> Int {
    switch letters {
    case ..<5: 0
    case ..<9: 1
    default: 2
    }
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
    JSONFile.write(terms, to: file)
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

extension String {
  /// Runs of letters and digits, lowercased, with where each starts.
  fileprivate var lowercasedWords: [(word: String, offset: Int)] {
    var words: [(word: String, offset: Int)] = []
    var current = ""
    for (offset, character) in lowercased().enumerated() {
      if character.isWordCharacter {
        current.append(character)
      } else if !current.isEmpty {
        words.append((current, offset - current.count))
        current = ""
      }
    }
    if !current.isEmpty { words.append((current, count - current.count)) }
    return words
  }
}

extension Character {
  fileprivate var isWordCharacter: Bool { isLetter || isNumber }
}

/// Edits from one string to the other: a letter inserted, removed, replaced, or two neighbours
/// swapped.
private func editDistance(_ first: String, _ second: String) -> Int {
  let first = Array(first)
  let second = Array(second)
  guard !first.isEmpty, !second.isEmpty else { return max(first.count, second.count) }
  var table = (0...first.count).map { row in (0...second.count).map { row == 0 ? $0 : 0 } }
  for row in 1...first.count {
    table[row][0] = row
    for column in 1...second.count {
      let replace = first[row - 1] == second[column - 1] ? 0 : 1
      var best = min(
        table[row - 1][column] + 1, table[row][column - 1] + 1,
        table[row - 1][column - 1] + replace)
      if row > 1, column > 1, first[row - 1] == second[column - 2],
        first[row - 2] == second[column - 1]
      {
        best = min(best, table[row - 2][column - 2] + 1)
      }
      table[row][column] = best
    }
  }
  return table[first.count][second.count]
}
