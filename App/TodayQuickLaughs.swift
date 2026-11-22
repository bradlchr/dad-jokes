import SwiftUI

struct TodayQuickLaughs: View {
  var library: JokeLibrary
  var date: Date
  var excluding: Joke
  var includesMature: Bool
  var showOnStage: (Joke, StagePlayback) -> Void

  @State private var revealed: Set<String> = []

  private var picks: [Joke] {
    let candidates = library.jokes.filter { joke in
      (includesMature || !joke.isMature) && joke.hasPunchline && joke.id != excluding.id
    }
    guard !candidates.isEmpty else { return [] }
    let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
    let count = min(3, candidates.count)
    return (0..<count).map { offset in
      candidates[(day + offset * (candidates.count / count)) % candidates.count]
    }
  }

  var body: some View {
    let jokes = picks
    if !jokes.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text("Quick laughs")
          .font(.system(.title3, design: .serif).weight(.bold))
          .accessibilityAddTraits(.isHeader)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
          ForEach(jokes) { joke in
            JokeTile(joke: joke, isFavorite: library.isFavorite(joke), revealed: Binding(
              get: { revealed.contains(joke.id) },
              set: { flipped in
                if flipped { revealed.insert(joke.id) } else { revealed.remove(joke.id) }
              }
            ), playOnStage: { showOnStage(joke, .autoplay) }) {
              Button(library.isFavorite(joke) ? "Remove Favorite" : "Add to Favorites",
                     systemImage: library.isFavorite(joke) ? "heart.slash" : "heart") {
                library.toggleFavorite(joke)
              }
              Button("Play on Stage", systemImage: "theatermasks") { showOnStage(joke, .manual) }
            }
          }
        }
      }
    }
  }
}
