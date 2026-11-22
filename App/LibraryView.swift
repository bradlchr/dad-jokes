import SwiftUI

enum LibraryFilter: Hashable {
  case all, favorites, category(String)

  var title: String {
    switch self {
    case .all: String(localized: "All jokes")
    case .favorites: String(localized: "Favorites")
    case .category(let name): name
    }
  }

  func includes(_ joke: Joke, isFavorite: Bool) -> Bool {
    switch self {
    case .all: true
    case .favorites: isFavorite
    case .category(let name): joke.categories.contains(name)
    }
  }
}

struct LibraryView: View {
  var library: JokeLibrary
  @Binding var filter: LibraryFilter
  var showOnStage: (Joke, StagePlayback) -> Void
  var openFile: () -> Void
  @AppStorage("include-mature-jokes") private var includesMature = false
  @State private var newJoke: Joke?

  private var results: [Joke] {
    library.jokes.filter { joke in
      (includesMature || !joke.isMature) && filter.includes(joke, isFavorite: library.isFavorite(joke))
    }
  }

  var body: some View {
    let jokes = results
    Group {
      if jokes.isEmpty {
        if filter == .favorites {
          ContentUnavailableView("No favorites yet", systemImage: "heart",
                                 description: Text("Add a joke to Favorites to keep it here."))
        } else {
          ContentUnavailableView("No jokes here", systemImage: "book.closed",
                                 description: Text("Add a joke or choose another category."))
        }
      } else {
        JokeGallery(jokes: jokes, library: library, heading: filter.title, showOnStage: showOnStage)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color("Stage").ignoresSafeArea())
    .navigationTitle("Library")
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        filterControl
        Button("Add joke", systemImage: "plus") {
          let categories: [String]
          if case .category(let name) = filter { categories = [name] } else { categories = [] }
          newJoke = Joke(setup: "", categories: categories)
        }
        .labelStyle(.iconOnly)
        .keyboardShortcut("n", modifiers: [.command, .shift])
        Menu("More library actions", systemImage: "ellipsis") {
          Button("Open Shared Joke…", systemImage: "folder", action: openFile)
        }
      }
    }
    .sheet(item: $newJoke) { joke in
      JokeEditor(joke: joke, library: library, existing: false)
    }
  }

  @ViewBuilder
  private var filterControl: some View {
    #if os(macOS)
    Menu {
      categoryPicker
        .pickerStyle(.inline)
    } label: {
      HStack(spacing: 6) {
        if filter == .all {
          Image(systemName: "books.vertical.fill")
            .accessibilityHidden(true)
        } else {
          CategoryArtwork(name: filter.title, size: 20)
        }
        Text(filter.title)
          .lineLimit(1)
      }
    }
    .accessibilityLabel("Filter jokes")
    .accessibilityValue(filter.title)
    #else
    categoryPicker
      .pickerStyle(.menu)
      .labelsHidden()
    #endif
  }

  private var categoryPicker: some View {
    Picker("Filter jokes", selection: $filter) {
      Label("All jokes", systemImage: "books.vertical.fill").tag(LibraryFilter.all)
      Label { Text("Favorites") } icon: { CategoryArtwork(name: "Favorites") }
        .tag(LibraryFilter.favorites)
      Divider()
      ForEach(library.categories) { category in
        Label { Text(category.name) } icon: { CategoryArtwork(name: category.name) }
          .tag(LibraryFilter.category(category.name))
      }
    }
    .labelStyle(.titleAndIcon)
  }
}
