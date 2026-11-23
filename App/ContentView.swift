import SwiftUI

struct ContentView: View {
  var library: JokeLibrary

  @AppStorage("joke-theme") private var theme: JokeTheme = .plum
  @AppStorage("include-mature-jokes") private var includesMature = false
  @AppStorage(StagePerformer.preferenceKey) private var favoritePerformer = StagePerformer.randomPreference
  @AppStorage("seen-whats-new-2") private var hasSeenWhatsNew = false
  @AppStorage("seen-library-narration-prompt") private var hasSeenNarrationPrompt = false
  @State private var showsWhatsNew = false
  @State private var showsNarrationPrompt = false
  @State private var selection: Destination? = .today
  @State private var dailyRequest = 0
  @State private var libraryFilter: LibraryFilter = .all
  @State private var search = ""
  @State private var performance: JokePerformance?
  @State private var maturePerformance: JokePerformance?
  @State private var pickingFile = false
  @State private var incomingFile: URL?
  @State private var fileError = false

  var body: some View {
    navigation
      .tint(theme.accent)
      .onOpenURL { url in
        if url == JokeCatalog.dailyURL {
          selection = .today
          dailyRequest += 1
        } else if url.isFileURL && url.pathExtension.caseInsensitiveCompare("dadjoke") == .orderedSame {
          showsWhatsNew = false
          incomingFile = url
        }
      }
      .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.dadJoke]) { result in
        switch result {
        case .success(let url): incomingFile = url
        case .failure: fileError = true
        }
      }
      .task(id: incomingFile) {
        guard let url = incomingFile else { return }
        let result = await Task.detached(priority: .userInitiated) {
          Result { try SharedJokeFile.open(url) }
        }.value
        guard !Task.isCancelled else { return }
        incomingFile = nil
        switch result {
        case .success(let joke): showOnStage(joke, .manual)
        case .failure: fileError = true
        }
      }
      .alert("Couldn’t open this joke", isPresented: $fileError) {
        Button("OK", role: .cancel) {}
      } message: {
        Text("Choose a valid .dadjoke file shared from Dad Jokes.")
      }
      .alert("This joke is marked mature", isPresented: Binding(
        get: { maturePerformance != nil }, set: { if !$0 { maturePerformance = nil } }
      ), presenting: maturePerformance) { requested in
        Button("Play Joke") { performance = requested }
        Button("Cancel", role: .cancel) {}
      } message: { _ in
        Text("Play it once with your current audience settings.")
      }
      .task {
        guard !hasSeenWhatsNew, incomingFile == nil, performance == nil else { return }
        showsWhatsNew = true
      }
      .onChange(of: selection) { presentNarrationPrompt() }
      .onChange(of: library.categories.map(\.name)) { _, names in
        if let category = libraryFilter.category, !names.contains(category) {
          libraryFilter.category = library.archive.renamedDefaultCategories?[category]
            .flatMap { names.contains($0) ? $0 : nil }
        }
      }
      .alert("Optimize Joke Delivery?", isPresented: $showsNarrationPrompt) {
        if library.narrationOptimizer.isAvailable {
          Button("Optimize Library") { library.narrationOptimizer.optimizeLibrary(library) }
          Button("Not Now", role: .cancel) {}
        } else {
          Button("OK", role: .cancel) {}
        }
      } message: {
        if library.narrationOptimizer.isAvailable {
          Text("Apple Intelligence can prepare your saved jokes for the stage on this device. Your written jokes stay as you entered them. You can also do this later in Settings.")
        } else {
          Text(JokeSpeech.availabilityMessage)
        }
      }
      .sheet(isPresented: $showsWhatsNew, onDismiss: presentNarrationPrompt) {
        WhatsNewView(library: library) { openLibrary in
          hasSeenWhatsNew = true
          showsWhatsNew = false
          if openLibrary { selection = .library }
        }
        .interactiveDismissDisabled()
      }
      #if os(macOS)
      .sheet(item: $performance) { performance in
        JokeStageSession(initial: performance, library: library)
          .frame(minWidth: 530, idealWidth: 700, minHeight: 610, idealHeight: 740)
      }
      #else
      .fullScreenCover(item: $performance) { performance in
        JokeStageSession(initial: performance, library: library)
      }
      #endif
  }

  @ViewBuilder
  private var navigation: some View {
    #if os(macOS)
    NavigationSplitView {
      List([Destination.today, .library, .search], selection: $selection) { destination in
        Label(destination.title, systemImage: destination.symbol)
          .tag(destination)
      }
      .navigationTitle("Dad Jokes")
      .navigationSplitViewColumnWidth(min: 160, ideal: 185)
    } detail: {
      screen(selection ?? .today)
    }
    #else
    TabView(selection: Binding(get: { selection ?? .today }, set: { selection = $0 })) {
      Tab("Today", systemImage: "sun.max.fill", value: Destination.today) {
        screen(.today)
      }
      Tab("Library", systemImage: "books.vertical.fill", value: Destination.library) {
        screen(.library)
      }
      Tab("Settings", systemImage: "gearshape", value: Destination.settings) {
        screen(.settings)
      }
      Tab("Search", systemImage: "magnifyingglass", value: Destination.search, role: searchTabRole) {
        screen(.search)
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    #endif
  }

  #if os(iOS)
  private var searchTabRole: TabRole {
    if #available(iOS 27.0, *) { return .prominent }
    return .search
  }
  #endif

  private func screen(_ destination: Destination) -> some View {
    NavigationStack {
      switch destination {
      case .today:
        TodayView(library: library, theme: theme, dailyRequest: dailyRequest, showOnStage: showOnStage) { filter in
          libraryFilter = filter
          selection = .library
        }
      case .library:
        LibraryView(library: library, filter: $libraryFilter, isSelected: selection == .library,
                    showOnStage: showOnStage,
                    openFile: { pickingFile = true })
      case .search:
        JokeSearchView(library: library, search: $search, isSelected: selection == .search, showOnStage: showOnStage)
      case .settings:
        PreferencesView(library: library, theme: $theme)
      }
    }
  }

  private func showOnStage(_ joke: Joke, _ playback: StagePlayback) {
    let latest = library.currentVersion(of: joke)
    let requested = JokePerformance(joke: latest, performer: .select(preference: favoritePerformer),
                                    autoplay: playback == .autoplay)
    if latest.isMature && !includesMature {
      maturePerformance = requested
    } else {
      performance = requested
    }
  }

  private func presentNarrationPrompt() {
    guard selection == .library, hasSeenWhatsNew, !showsWhatsNew, !hasSeenNarrationPrompt else { return }
    library.narrationOptimizer.refresh(for: library)
    hasSeenNarrationPrompt = true
    showsNarrationPrompt = true
  }

}

private enum Destination: String, Identifiable {
  case today, library, search, settings

  var id: Self { self }
  var title: LocalizedStringKey {
    switch self {
    case .today: "Today"
    case .library: "Library"
    case .search: "Search"
    case .settings: "Settings"
    }
  }
  var symbol: String {
    switch self {
    case .today: "sun.max.fill"
    case .library: "books.vertical.fill"
    case .search: "magnifyingglass"
    case .settings: "gearshape"
    }
  }
}
