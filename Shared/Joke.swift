import Foundation

struct Joke: Codable, Equatable, Identifiable, Sendable {
  var id: String = UUID().uuidString
  var setup: String
  var punchline = ""
  var categories: [String] = []
  var isMature = false
  var dateAdded: Date?
  var narration: JokeNarration?
  var artwork: Data?

  var text: String {
    punchline.isEmpty ? setup : "\(setup)\n\(punchline)"
  }

  var hasPunchline: Bool { !punchline.isEmpty }

  static func split(_ text: String) -> (setup: String, punchline: String) {
    guard let question = text.indices.reversed().first(where: { index in
      let next = text.index(after: index)
      return text[index] == "?" && next < text.endIndex && text[next].isWhitespace
    }) else { return (text, "") }
    let punchline = text[text.index(after: question)...].trimmingCharacters(in: .whitespacesAndNewlines)
    return punchline.isEmpty ? (text, "") : (String(text[...question]), punchline)
  }

  var normalizedText: String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ").lowercased()
  }
}

struct JokeNarration: Codable, Equatable, Sendable {
  var setup: String
  var punchline: String
}
