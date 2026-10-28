// Word-level diff between two versions of a text. See docs/specs/04-prompts.md §2.

import Foundation

/// One edit between two versions. `old` and `new` keep the exact characters of the edit,
/// so the segments of a diff rebuild either version.
public struct Change: Hashable, Sendable, Identifiable {
  /// 1-based number, the one Explain refers to.
  public let id: Int
  public let old: String
  public let new: String

  /// Old and new text without surrounding whitespace, for the list of changes.
  public var words: [String] { [old, new].map(\.trimmed) }
}

public enum DiffSegment: Hashable, Sendable {
  case same(String)
  case changed(Change)
}

public struct TextDiff: Hashable, Sendable {
  public let segments: [DiffSegment]

  /// Changes separated by at most one unchanged word are merged into one.
  public init(old: String, new: String) {
    var builder = SegmentBuilder()
    for operation in WordAlignment(old: words(old), new: words(new)).operations() {
      builder.add(operation)
    }
    segments = builder.finish()
  }

  public var changes: [Change] {
    segments.compactMap { segment in
      guard case .changed(let change) = segment else { return nil }
      return change
    }
  }

  public var newText: String { text(rejecting: nil) }

  /// The new text with one change reverted to the old words.
  public func text(rejecting rejected: Change?) -> String {
    segments.map { segment in
      switch segment {
      case .same(let text): text
      case .changed(let change): change == rejected ? change.old : change.new
      }
    }.joined()
  }
}

extension String {
  var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Splits text into alternating runs of whitespace and non-whitespace.
private func words(_ text: String) -> [String] {
  var result: [String] = []
  var current = ""
  for character in text {
    if let last = current.last, last.isWhitespace != character.isWhitespace {
      result.append(current)
      current = ""
    }
    current.append(character)
  }
  if !current.isEmpty { result.append(current) }
  return result
}

private enum Operation {
  case same(String)
  case delete(String)
  case insert(String)
}

/// Longest common subsequence alignment of two token lists.
private struct WordAlignment {
  let old: [String]
  let new: [String]
  private var table: [Int]

  init(old: [String], new: [String]) {
    self.old = old
    self.new = new
    table = Array(repeating: 0, count: (old.count + 1) * (new.count + 1))
    for i in stride(from: old.count - 1, through: 0, by: -1) {
      for j in stride(from: new.count - 1, through: 0, by: -1) {
        let value =
          old[i] == new[j] ? length(i + 1, j + 1) + 1 : max(length(i + 1, j), length(i, j + 1))
        table[i * (new.count + 1) + j] = value
      }
    }
  }

  private func length(_ i: Int, _ j: Int) -> Int { table[i * (new.count + 1) + j] }

  func operations() -> [Operation] {
    var result: [Operation] = []
    var i = 0
    var j = 0
    while i < old.count || j < new.count {
      if i < old.count, j < new.count, old[i] == new[j] {
        result.append(.same(old[i]))
        i += 1
        j += 1
      } else if j < new.count, i == old.count || length(i, j + 1) >= length(i + 1, j) {
        result.append(.insert(new[j]))
        j += 1
      } else {
        result.append(.delete(old[i]))
        i += 1
      }
    }
    return result
  }
}

/// Turns aligned operations into segments, merging changes that are one word apart.
private struct SegmentBuilder {
  private var segments: [DiffSegment] = []
  private var open: (old: String, new: String)?
  private var gap: [String] = []
  private var nextID = 1

  mutating func add(_ operation: Operation) {
    switch operation {
    case .same(let token): addSame(token)
    case .delete(let token): extendChange(old: token, new: "")
    case .insert(let token): extendChange(old: "", new: token)
    }
  }

  mutating func finish() -> [DiffSegment] {
    closeChange()
    return segments
  }

  private mutating func addSame(_ token: String) {
    guard open != nil else { return appendSame(token) }
    gap.append(token)
    if gap.count(where: { !$0.trimmed.isEmpty }) > 1 { closeChange() }
  }

  /// Adds to the open change; unchanged words since it become part of it.
  private mutating func extendChange(old: String, new: String) {
    let between = gap.joined()
    gap = []
    let current = open ?? ("", "")
    open = (current.old + between + old, current.new + between + new)
  }

  private mutating func closeChange() {
    guard let change = open else { return }
    open = nil
    if change.old.trimmed == change.new.trimmed {
      appendSame(change.new)
    } else {
      segments.append(.changed(Change(id: nextID, old: change.old, new: change.new)))
      nextID += 1
    }
    for token in gap { appendSame(token) }
    gap = []
  }

  private mutating func appendSame(_ text: String) {
    if case .same(let previous) = segments.last {
      segments[segments.count - 1] = .same(previous + text)
    } else {
      segments.append(.same(text))
    }
  }
}
