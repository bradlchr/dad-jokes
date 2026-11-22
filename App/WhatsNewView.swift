import SwiftUI

struct WhatsNewView: View {
  var library: JokeLibrary
  var finish: (Bool) -> Void
  @State private var page = Walkthrough.library

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Image(systemName: page.symbol)
            .font(.system(size: 33, weight: .semibold))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
          Text(page.title)
            .font(.system(.largeTitle, design: .serif).weight(.bold))
            .accessibilityAddTraits(.isHeader)
          Text(page.detail)
            .font(.body)
            .foregroundStyle(.secondary)
          if page == .library {
            Text(library.migrationMessage)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .padding(28)
        .frame(maxWidth: 500, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .background(Color("Stage").ignoresSafeArea())
      .navigationTitle("What’s New?")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Skip") { finish(false) }
        }
      }
      .safeAreaInset(edge: .bottom) {
        HStack {
          if let previous = Walkthrough(rawValue: page.rawValue - 1) {
            Button("Back") { page = previous }
          }
          Spacer()
          if let next = Walkthrough(rawValue: page.rawValue + 1) {
            Button("Continue") { page = next }
              .buttonStyle(.borderedProminent)
          } else {
            Button("Open Library") { finish(true) }
              .buttonStyle(.borderedProminent)
          }
        }
        .padding(22)
        .background(.bar)
      }
    }
    #if os(macOS)
    .frame(minWidth: 470, minHeight: 380)
    #endif
  }
}

private enum Walkthrough: Int {
  case library, today, stage

  var title: LocalizedStringKey {
    switch self {
    case .library: "Your jokes live here"
    case .today: "Find something new"
    case .stage: "Take it to the stage"
    }
  }

  var detail: LocalizedStringKey {
    switch self {
    case .library: "Find your jokes, categories, and favorites in Library. Flip a card for the punchline. To see jokes marked for adults, turn on Include Mature Jokes in Settings."
    case .today: "Today has a daily joke and fresh picks from the web. Online cards have a dotted border and an option to save them."
    case .stage: "Play jokes in Dad Jokes Live, then keep the show going with Another Joke. Pick a favorite dad in Settings, or leave the lineup random."
    }
  }

  var symbol: String {
    switch self {
    case .library: "books.vertical.fill"
    case .today: "sun.max.fill"
    case .stage: "theatermasks"
    }
  }
}
