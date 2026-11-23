import Foundation

enum LibrarySort: String, CaseIterable {
  case dateAdded, favoritesFirst, category, manual, random

  var title: LocalizedStringResource {
    switch self {
    case .dateAdded: "Date Added"
    case .favoritesFirst: "Favorites First"
    case .category: "Category"
    case .manual: "Manual"
    case .random: "Random"
    }
  }

  @MainActor
  func ordered(_ jokes: [Joke], library: JokeLibrary, randomOrder: [String], category: String?) -> [Joke] {
    switch self {
    case .dateAdded:
      return jokes.sorted(by: newestFirst)
    case .favoritesFirst:
      return jokes.sorted {
        let lhs = library.isFavorite($0)
        let rhs = library.isFavorite($1)
        return lhs == rhs ? newestFirst($0, $1) : lhs
      }
    case .category:
      let categories = jokes.map {
        category ?? $0.categories.min { $0.localizedStandardCompare($1) == .orderedAscending }
      }
      return jokes.indices.sorted { lhs, rhs in
        switch (categories[lhs], categories[rhs]) {
        case (let a?, let b?):
          let order = a.localizedStandardCompare(b)
          if order != .orderedSame { return order == .orderedAscending }
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): break
        }
        return newestFirst(jokes[lhs], jokes[rhs])
      }.map { jokes[$0] }
    case .manual:
      return applying(library.manualOrder, to: jokes)
    case .random:
      return applying(randomOrder, to: jokes)
    }
  }

  private func newestFirst(_ lhs: Joke, _ rhs: Joke) -> Bool {
    (lhs.dateAdded ?? .distantPast) > (rhs.dateAdded ?? .distantPast)
  }

  private func applying(_ order: [String], to jokes: [Joke]) -> [Joke] {
    var remaining = Dictionary(jokes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let ordered = order.compactMap { remaining.removeValue(forKey: $0) }
    return ordered + jokes.filter { remaining[$0.id] != nil }
  }
}
