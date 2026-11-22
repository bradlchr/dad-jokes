import Accessibility
import SwiftUI

struct ContentView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var date = Date()
  @State private var shuffledJoke: Joke?
  @State private var deck: [Joke] = []
  @State private var revealed = false
  @State private var revealCount = 0

  private let lavender = Color(red: 0.79, green: 0.69, blue: 1)

  private var joke: Joke { shuffledJoke ?? JokeCatalog.daily(on: date) }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Label(shuffledJoke == nil ? "Joke of the day" : "From the classics",
                systemImage: "mustache.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tint)
          Text(joke.setup)
            .font(.system(.title3, design: .serif).weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
          if joke.hasPunchline {
            if revealed {
              Text(joke.punchline)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            } else {
              Button(action: reveal) {
                Label("Reveal punchline", systemImage: "sparkles")
                  .foregroundStyle(.black)
              }
              .buttonStyle(.borderedProminent)
            }
          }
          Button("Another joke", systemImage: "shuffle", action: shuffle)
            .buttonStyle(.bordered)
          if shuffledJoke != nil {
            Button("Today’s joke", systemImage: "sun.max.fill", action: showDaily)
              .buttonStyle(.plain)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 5)
        .padding(.bottom, 8)
      }
      .navigationTitle("Dad Jokes")
    }
    .tint(lavender)
    .sensoryFeedback(.success, trigger: revealCount)
    .onOpenURL { url in if url == JokeCatalog.dailyURL { showDaily() } }
    .onChange(of: scenePhase) {
      if scenePhase == .active && shuffledJoke == nil &&
          !Calendar.current.isDateInToday(date) { showDaily() }
    }
  }

  private func reveal() {
    withAnimation(reduceMotion ? nil : .smooth) { revealed = true }
    revealCount += 1
    AccessibilityNotification.Announcement(joke.punchline).post()
  }

  private func shuffle() {
    if deck.isEmpty {
      deck = JokeCatalog.jokes.filter { !$0.isMature }.shuffled()
      if deck.first?.id == joke.id && deck.count > 1 { deck.swapAt(0, 1) }
    }
    guard !deck.isEmpty else { return }
    shuffledJoke = deck.removeFirst()
    revealed = false
  }

  private func showDaily() {
    date = Date()
    shuffledJoke = nil
    revealed = false
  }
}
