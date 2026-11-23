import SwiftUI
import UniformTypeIdentifiers

struct JokeArchive: Codable, Sendable {
  var jokes: [Joke]
  var favorites: Set<String> = []
  var groans: Set<String> = []
  var categoryNames: Set<String> = []
  var categoryIcons: [String: Data]?
  var renamedDefaultCategories: [String: String]?
  var removedCategories: Set<String>?

  static func decode(_ data: Data) throws -> Self {
    let decoder = JSONDecoder()
    if let archive = try? decoder.decode(Self.self, from: data) { return archive }
    let legacy = try decoder.decode([LegacyJoke].self, from: data)
    var favorites: Set<String> = []
    let jokes = legacy.map { item in
      let parts = Joke.split(item.jokeText)
      let names = (item.categories ?? []).map(\.name)
      let joke = Joke(setup: parts.setup, punchline: parts.punchline,
                      categories: names.filter { $0 != "Favorites" },
                      isMature: item.isAdult ?? item.adult ?? (item.ageLevel != 0))
      if names.contains("Favorites") { favorites.insert(joke.id) }
      return joke
    }
    return Self(jokes: jokes, favorites: favorites)
  }

  private struct LegacyJoke: Decodable {
    struct Category: Decodable { var name: String }
    var jokeText: String
    var categories: [Category]?
    var isAdult: Bool?
    var adult: Bool?
    var ageLevel: Int?
  }
}

struct JokeArchiveDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.json]
  var archive: JokeArchive

  init(archive: JokeArchive) {
    self.archive = archive
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    archive = try JokeArchive.decode(data)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return FileWrapper(regularFileWithContents: try encoder.encode(archive))
  }
}
