// A JSON file of the user's data in Application Support, read once and written whole: the
// dictionary (02 M11) and the user's prompts (02 M8).

import Foundation

enum JSONFile {
  /// ~/Library/Application Support/Cyrano/<name>
  static func standard(_ name: String) -> URL {
    URL.applicationSupportDirectory.appending(path: "Cyrano/\(name)")
  }

  /// Nil without a file. A file that can't be read is kept next to it as `.bak`, so the next
  /// change doesn't overwrite the user's data.
  static func read<Value: Decodable>(_ type: Value.Type, from file: URL) -> Value? {
    guard let data = try? Data(contentsOf: file) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let value = try? decoder.decode(type, from: data) { return value }
    let backup = file.appendingPathExtension("bak")
    try? FileManager.default.removeItem(at: backup)
    try? FileManager.default.moveItem(at: file, to: backup)
    return nil
  }

  static func write(_ value: some Encodable, to file: URL) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try? FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    // A failed write keeps the data in memory for this run; the next change writes again.
    try? encoder.encode(value).write(to: file, options: .atomic)
  }
}
