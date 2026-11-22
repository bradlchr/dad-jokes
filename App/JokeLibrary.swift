import Foundation
import Observation

@Observable
@MainActor
final class JokeLibrary {
  let narrationOptimizer = JokeNarrationOptimizer()
  private(set) var archive = JokeLibrary.loadArchive()
  private(set) var migration = Migration.checking
  private var deck: [String] = []
  private var deckAllowsMature = false
  private var recoveredCount = JokeLibrary.loadSavedLibrary()?.recoveredCount

  nonisolated static let storageKey = "joke-library-v1"
  private nonisolated static var libraryFile: URL {
    URL.applicationSupportDirectory.appending(path: "DadJokesLibrary/Library.json")
  }

  private var isRecovering = false
  var migrationMessage: String {
    switch migration {
    case .checking: String(localized: "Checking for your original library…")
    case .recovered(let count): String(localized: "Your original library is ready in Library. \(count) jokes were recovered.")
    case .unavailable: String(localized: "You can check for an original library again or import a backup in Settings.")
    case .failed: String(localized: "Your original library couldn’t be read right now. You can try again in Settings.")
    }
  }

  var canRetryRecovery: Bool {
    switch migration {
    case .unavailable, .failed: true
    case .checking, .recovered: false
    }
  }

  var jokes: [Joke] { archive.jokes }
  var categories: [JokeCategory] {
    let custom = Set(jokes.flatMap(\.categories))
      .union(archive.categoryNames)
      .subtracting(JokeCatalog.categories.map(\.name))
    return (JokeCatalog.categories.filter { $0.name != "Favorites" }
            + custom.filter { $0 != "Favorites" }.map { JokeCategory(name: $0, image: "tag") })
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  func contains(_ joke: Joke) -> Bool { jokes.contains { $0.id == joke.id } }
  func hasCopy(of joke: Joke) -> Bool {
    let text = joke.normalizedText
    return jokes.contains { $0.id == joke.id || $0.normalizedText == text }
  }

  @discardableResult
  func addIfNew(_ joke: Joke) -> Bool {
    guard !hasCopy(of: joke) else { return false }
    save(joke)
    return true
  }

  func isFavorite(_ joke: Joke) -> Bool { archive.favorites.contains(joke.id) }
  func hasGroaned(_ joke: Joke) -> Bool { archive.groans.contains(joke.id) }

  func save(_ joke: Joke) {
    var updated = joke
    let previous = jokes.first { $0.id == joke.id }
    let textChanged = previous?.setup != joke.setup || previous?.punchline != joke.punchline
    updated.narration = textChanged ? nil : previous?.narration
    if let index = archive.jokes.firstIndex(where: { $0.id == joke.id }) {
      archive.jokes[index] = updated
    } else {
      archive.jokes.insert(updated, at: 0)
    }
    archive.categoryNames.formUnion(joke.categories)
    saveArchive()
    if textChanged { narrationOptimizer.schedule(updated, in: self) }
  }

  func applyNarration(_ narration: JokeNarration, to original: Joke) {
    guard let index = archive.jokes.firstIndex(where: { $0.id == original.id }),
          archive.jokes[index].setup == original.setup,
          archive.jokes[index].punchline == original.punchline,
          archive.jokes[index].narration != narration else { return }
    archive.jokes[index].narration = narration
    saveArchive()
  }

  func currentVersion(of joke: Joke) -> Joke {
    jokes.first { $0.id == joke.id } ?? joke
  }

  func delete(_ joke: Joke) {
    archive.jokes.removeAll { $0.id == joke.id }
    archive.favorites.remove(joke.id)
    archive.groans.remove(joke.id)
    saveArchive()
  }

  func toggleFavorite(_ joke: Joke) {
    if !archive.favorites.insert(joke.id).inserted {
      archive.favorites.remove(joke.id)
    } else if !contains(joke) {
      archive.jokes.insert(joke, at: 0)
    }
    saveArchive()
  }

  func toggleGroan(_ joke: Joke) {
    if !archive.groans.insert(joke.id).inserted { archive.groans.remove(joke.id) }
    saveArchive()
  }

  func next(excluding currentID: String, allowsMature: Bool) -> Joke? {
    let candidates = jokes.filter { allowsMature || !$0.isMature }
    if deck.isEmpty || deckAllowsMature != allowsMature {
      deck = candidates.map(\.id).shuffled()
      deckAllowsMature = allowsMature
      if deck.first == currentID, deck.count > 1 {
        deck.swapAt(0, 1)
      }
    }
    while !deck.isEmpty {
      let id = deck.removeFirst()
      if id != currentID, let joke = candidates.first(where: { $0.id == id }) {
        return joke
      }
    }
    return candidates.filter { $0.id != currentID }.randomElement()
  }

  @discardableResult
  func merge(_ incoming: JokeArchive) -> Int {
    let (merged, count) = Self.merging(incoming, into: archive)
    archive = merged
    saveArchive()
    return count
  }

  func recoverOriginalLibrary() async {
    guard !isRecovering else { return }
    if let previous = recoveredCount {
      migration = .recovered(previous)
      return
    }
    isRecovering = true
    migration = .checking
    defer { isRecovering = false }
    do {
      let local = try await Task.detached(priority: .userInitiated) {
        try LegacyLibraryMigration.localArchive()
      }.value
      try Task.checkCancellation()
      let recovered: JokeArchive?
      if let local {
        recovered = local
      } else {
        let cloud = try await LegacyLibraryMigration.cloudArchive()
        recovered = cloud.flatMap { $0.jokes.isEmpty && $0.categoryNames.isEmpty ? nil : $0 }
      }
      try Task.checkCancellation()
      guard let recovered else {
        migration = .unavailable
        return
      }
      let result = if Self.loadSavedLibrary() == nil && UserDefaults.standard.data(forKey: Self.storageKey) == nil {
        recovered
      } else {
        Self.merging(recovered, into: archive, preserveCategories: true).0
      }
      try Self.writeLibrary(SavedLibrary(archive: result, recoveredCount: recovered.jokes.count))
      archive = result
      recoveredCount = recovered.jokes.count
      deck.removeAll()
      migration = .recovered(recovered.jokes.count)
    } catch is CancellationError {
      migration = .failed
    } catch {
      migration = .failed
    }
  }

  private static func merging(_ incoming: JokeArchive, into current: JokeArchive,
                              preserveCategories: Bool = false) -> (JokeArchive, Int) {
    var result = current
    var existingByText = Dictionary(current.jokes.enumerated().map { ($0.element.normalizedText, $0.offset) },
                                    uniquingKeysWith: { current, _ in current })
    var usedIDs = Set(current.jokes.map(\.id))
    var inserted: [Joke] = []
    let originalCount = current.jokes.count
    for var joke in incoming.jokes where !joke.setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      let oldID = joke.id
      if let index = existingByText[joke.normalizedText] {
        let existingID: String
        if index < originalCount {
          existingID = result.jokes[index].id
          if preserveCategories {
            let categories = result.jokes[index].categories
            result.jokes[index].categories = Array(Set(categories).union(joke.categories)).sorted()
            result.jokes[index].dateAdded = result.jokes[index].dateAdded ?? joke.dateAdded
          }
          // Keep distinct legacy entries with identical wording.
          if preserveCategories { existingByText.removeValue(forKey: joke.normalizedText) }
        } else {
          existingID = inserted[index - originalCount].id
        }
        if incoming.favorites.contains(oldID) { result.favorites.insert(existingID) }
        if incoming.groans.contains(oldID) { result.groans.insert(existingID) }
        continue
      }
      if usedIDs.contains(joke.id) { joke.id = UUID().uuidString }
      usedIDs.insert(joke.id)
      if !preserveCategories { existingByText[joke.normalizedText] = originalCount + inserted.count }
      inserted.append(joke)
      if incoming.favorites.contains(oldID) { result.favorites.insert(joke.id) }
      if incoming.groans.contains(oldID) { result.groans.insert(joke.id) }
    }
    result.jokes.insert(contentsOf: inserted, at: 0)
    result.categoryNames.formUnion(incoming.categoryNames)
    return (result, inserted.count)
  }

  nonisolated static func loadArchive() -> JokeArchive {
    if let saved = loadSavedLibrary() { return saved.archive }
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let archive = try? JSONDecoder().decode(JokeArchive.self, from: data) else {
      return JokeArchive(jokes: JokeCatalog.jokes)
    }
    return archive
  }

  private func saveArchive() {
    try? Self.writeLibrary(SavedLibrary(archive: archive, recoveredCount: recoveredCount))
  }

  private nonisolated static func loadSavedLibrary() -> SavedLibrary? {
    guard let data = try? Data(contentsOf: libraryFile) else { return nil }
    return try? JSONDecoder().decode(SavedLibrary.self, from: data)
  }

  private nonisolated static func writeLibrary(_ library: SavedLibrary) throws {
    let data = try JSONEncoder().encode(library)
    try FileManager.default.createDirectory(at: libraryFile.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try data.write(to: libraryFile, options: .atomic)
  }

  enum Migration {
    case checking, recovered(Int), unavailable, failed
  }

  private struct SavedLibrary: Codable {
    var archive: JokeArchive
    var recoveredCount: Int?
  }
}
