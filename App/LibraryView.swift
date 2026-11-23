import SwiftUI

struct LibraryFilter: Hashable {
  var category: String?
  var favoritesOnly = false

  static let all = Self()
  static let favorites = Self(favoritesOnly: true)

  static func category(_ name: String) -> Self { Self(category: name) }

  var title: String {
    switch (category, favoritesOnly) {
    case (let name?, true): String(localized: "\(name) favorites")
    case (let name?, false): name
    case (nil, true): String(localized: "Favorites")
    case (nil, false): String(localized: "All jokes")
    }
  }

  func includes(_ joke: Joke, isFavorite: Bool) -> Bool {
    (!favoritesOnly || isFavorite) && (category.map { joke.categories.contains($0) } ?? true)
  }
}

struct LibraryView: View {
  var library: JokeLibrary
  @Binding var filter: LibraryFilter
  var isSelected: Bool
  var showOnStage: (Joke, StagePlayback) -> Void
  var openFile: () -> Void
  @AppStorage("include-mature-jokes") private var includesMature = false
  @AppStorage("library-sort") private var sort: LibrarySort = .dateAdded
  @State private var randomOrder: [String] = []
  @State private var newJoke: Joke?

  private var filteredJokes: [Joke] {
    library.jokes.filter { joke in
      (includesMature || !joke.isMature) && filter.includes(joke, isFavorite: library.isFavorite(joke))
    }
  }

  var body: some View {
    let jokes = sort.ordered(filteredJokes, library: library, randomOrder: randomOrder,
                             category: filter.category)
    Group {
      if jokes.isEmpty {
        VStack(alignment: .leading, spacing: 14) {
          JokeGalleryHeading(title: filter.title, sort: sort)
            .frame(maxWidth: 1160, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .frame(maxWidth: .infinity)
          Group {
            if filter.favoritesOnly {
              ContentUnavailableView("No favorites here", systemImage: "heart",
                                     description: Text("Add a favorite or change your filters."))
            } else {
              ContentUnavailableView("No jokes here", systemImage: "book.closed",
                                     description: Text("Add a joke or choose another category."))
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        JokeGallery(jokes: jokes, library: library, heading: filter.title, showOnStage: showOnStage,
                    allowsReordering: sort == .manual, sort: sort)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color("Stage").ignoresSafeArea())
    .navigationTitle("Library")
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        filterControl
        Menu {
          Picker("Sort by", selection: $sort) {
            ForEach(LibrarySort.allCases, id: \.self) { option in
              Text(option.title).tag(option)
            }
          }
          .pickerStyle(.inline)
          Divider()
          Button("Open Shared Joke…", systemImage: "folder", action: openFile)
        } label: {
          Label("Sort and library actions", systemImage: "arrow.up.arrow.down")
            .labelStyle(.iconOnly)
        }
        .accessibilityValue(Text(sort.title))
        if sort == .random {
          Button("Shuffle jokes", systemImage: "shuffle", action: shuffle)
            .labelStyle(.iconOnly)
            .disabled(jokes.count < 2)
        }
        Button("Add joke", systemImage: "plus") {
          newJoke = Joke(setup: "", categories: filter.category.map { [$0] } ?? [])
        }
        .labelStyle(.iconOnly)
        .keyboardShortcut("n", modifiers: [.command, .shift])
      }
    }
    .onChange(of: isSelected, initial: true) {
      if isSelected && sort == .random { shuffle() }
    }
    .onChange(of: sort) {
      if sort == .random { shuffle() }
    }
    .sheet(item: $newJoke) { joke in
      JokeEditor(joke: joke, library: library, existing: false)
    }
  }

  private var filterControl: some View {
    Menu {
      Toggle("Favorites Only", systemImage: "heart", isOn: $filter.favoritesOnly)
      Divider()
      Picker("Category", selection: $filter.category) {
        Label("All Categories", systemImage: "books.vertical.fill").tag(nil as String?)
        ForEach(library.categories) { category in
          Label {
            Text(category.name)
          } icon: {
            CategoryArtwork(name: category.name, size: 18)
          }
          .tag(Optional(category.name))
        }
      }
      .pickerStyle(.inline)
    } label: {
      HStack(spacing: 6) {
        if let category = filter.category {
          CategoryArtwork(name: category, size: 18)
        } else {
          Image(systemName: filter.favoritesOnly ? "heart.fill" : "books.vertical.fill")
        }
        #if os(macOS)
        Text(filter.title)
          .lineLimit(1)
        #endif
      }
      .accessibilityLabel("Filter jokes")
    }
    .accessibilityValue(filter.title)
  }

  private func shuffle() {
    let visible = filteredJokes
    let previous = LibrarySort.random.ordered(visible, library: library, randomOrder: randomOrder,
                                               category: filter.category).map(\.id)
    let visibleIDs = Set(previous)
    var next = library.jokes.map(\.id).shuffled()
    if previous.count > 1, next.filter({ visibleIDs.contains($0) }) == previous,
       let first = next.firstIndex(of: previous[0]), let second = next.firstIndex(of: previous[1]) {
      next.swapAt(first, second)
    }
    randomOrder = next
  }
}
