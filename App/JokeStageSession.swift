import SwiftUI

struct JokeStageSession: View {
  var library: JokeLibrary

  @AppStorage(StagePerformer.preferenceKey) private var favoritePerformer = StagePerformer.randomPreference
  @AppStorage("include-mature-jokes") private var includesMature = false
  @State private var current: JokePerformance

  init(initial: JokePerformance, library: JokeLibrary) {
    self.library = library
    _current = State(initialValue: initial)
  }

  private var hasAnother: Bool {
    library.jokes.contains { $0.id != current.joke.id && (includesMature || !$0.isMature) }
  }

  var body: some View {
    JokePerformanceView(performance: current, library: library,
                        anotherJoke: hasAnother ? playAnother : nil)
      .id(current.id)
  }

  private func playAnother() {
    guard let next = library.next(excluding: current.joke.id, allowsMature: includesMature) else { return }
    current = JokePerformance(joke: next,
                              performer: .select(preference: favoritePerformer, excluding: current.performer),
                              autoplay: true)
  }
}
