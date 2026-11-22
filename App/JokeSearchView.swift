import SwiftUI

struct JokeSearchView: View {
  var library: JokeLibrary
  @Binding var search: String
  var isSelected: Bool
  var showOnStage: (Joke, StagePlayback) -> Void
  #if os(iOS)
  @State private var searchPresented = false
  #else
  @FocusState private var searchFocused: Bool
  #endif
  @AppStorage("include-mature-jokes") private var includesMature = false

  var body: some View {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    Group {
      if query.isEmpty {
        ContentUnavailableView("Find a joke", systemImage: "magnifyingglass",
                               description: Text("Search by setup, punchline, or category."))
      } else {
        let results = library.jokes.filter { joke in
          (includesMature || !joke.isMature) && (joke.text.localizedStandardContains(query)
            || joke.categories.contains { $0.localizedStandardContains(query) })
        }
        if results.isEmpty {
          ContentUnavailableView.search(text: query)
        } else {
          JokeGallery(jokes: results, library: library, heading: String(localized: "Search results"),
                      showOnStage: showOnStage)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color("Stage").ignoresSafeArea())
    .navigationTitle("Search")
    #if os(iOS)
    .searchable(text: $search, isPresented: $searchPresented,
                placement: .navigationBarDrawer(displayMode: .always), prompt: "Search jokes")
    #else
    .searchFocused($searchFocused)
    .searchable(text: $search, prompt: "Search jokes")
    #endif
    .task(id: isSelected) {
      guard isSelected, query.isEmpty else { return }
      await Task.yield()
      guard !Task.isCancelled else { return }
      #if os(iOS)
      searchPresented = true
      #else
      searchFocused = true
      #endif
    }
  }
}
