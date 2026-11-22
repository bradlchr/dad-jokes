import Accessibility
import SwiftUI

struct TodayView: View {
  var library: JokeLibrary
  var theme: JokeTheme
  var dailyRequest: Int
  var showOnStage: (Joke, StagePlayback) -> Void
  var openLibrary: (LibraryFilter) -> Void

  @AppStorage("include-mature-jokes") private var includesMature = false
  @AppStorage("reveal-punchlines") private var hidesPunchlines = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var typeSize

  @State private var date = Date()
  @State private var shuffledJoke: Joke?
  @State private var revealed = false
  @State private var onlineJoke: Joke?
  @State private var onlineRequest = 0
  @State private var isLoadingOnline = false
  @State private var allowsOnlinePreview = false
  @State private var confirmsOnline = false
  @State private var onlineFailed = false
  @State private var savingOnline: Joke?
  @State private var revealCount = 0
  @State private var groanCount = 0

  private var daily: Joke { JokeCatalog.daily(on: date) }
  private var joke: Joke { library.currentVersion(of: onlineJoke ?? shuffledJoke ?? daily) }
  private var isDaily: Bool { onlineJoke == nil && shuffledJoke == nil }
  private var hasUnsavedOnlineJoke: Bool { onlineJoke != nil && !library.hasCopy(of: joke) }
  private var isVisible: Bool { revealed || !hidesPunchlines || !joke.hasPunchline }
  private var canShuffle: Bool { library.jokes.contains { $0.id != joke.id && (includesMature || !$0.isMature) } }

  var body: some View {
    ScrollViewReader { scroll in
      layout
        .onChange(of: onlineJoke?.id) {
          if onlineJoke != nil { scroll.scrollTo("joke-ticket", anchor: .top) }
        }
    }
    .background(Color("Stage").ignoresSafeArea())
    #if os(iOS)
    .toolbarVisibility(.hidden, for: .navigationBar)
    #endif
    .onChange(of: includesMature) {
      if !includesMature {
        allowsOnlinePreview = false
        if joke.isMature { showDaily() }
      }
    }
    .onChange(of: dailyRequest) { showDaily() }
    .onChange(of: scenePhase) { if scenePhase == .active { updateDate() } }
    .task {
      updateDate()
      while !Task.isCancelled {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let midnight = calendar.date(byAdding: .day, value: 1, to: start)
          ?? start.addingTimeInterval(86400)
        do { try await Task.sleep(for: .seconds(max(midnight.timeIntervalSinceNow, 1))) }
        catch { break }
        updateDate()
      }
    }
    .task(id: onlineRequest) {
      if onlineRequest != 0 && isLoadingOnline { await loadOnlineJoke() }
    }
    .alert("Online jokes are unrated", isPresented: $confirmsOnline) {
      Button("Find a Joke") {
        allowsOnlinePreview = true
        requestOnline()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The web feed may include mature jokes. You can review a joke before saving it.")
    }
    .alert("Couldn’t find a new online joke", isPresented: $onlineFailed) {
      Button("Try Again") { requestOnline() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The online feed may be unavailable or may have returned jokes already in your library.")
    }
    .sheet(item: $savingOnline) { joke in
      JokeEditor(joke: joke, library: library, existing: false)
    }
    #if os(iOS)
    .sensoryFeedback(.impact(weight: .light), trigger: revealCount)
    .sensoryFeedback(.success, trigger: groanCount)
    #endif
  }

  private var layout: some View {
    DuoLayout { size in
      let wide = size.width >= 700 && !typeSize.isAccessibilitySize
      let sideWidth = min(size.width * 0.34, 350)
      ScrollView {
        VStack(alignment: .leading, spacing: wide ? 24 : 19) {
          TodayHeader(theme: theme, date: date)
          if wide {
            Grid(alignment: .topLeading, horizontalSpacing: 24, verticalSpacing: 24) {
              GridRow {
                VStack(spacing: 15) {
                  ticket
                  jokeActions
                }
                TodayStageCard { showOnStage(joke, .manual) }
                  .frame(width: sideWidth)
              }
              GridRow {
                TodayCategories(library: library, includesMature: includesMature,
                                theme: theme, openLibrary: openLibrary)
                explorePanel(includeStage: false)
                  .frame(width: sideWidth)
              }
              GridRow {
                TodayQuickLaughs(library: library, date: date, excluding: joke,
                                 includesMature: includesMature, showOnStage: showOnStage)
                  .gridCellColumns(2)
              }
            }
          } else {
            ticket
            jokeActions
            explorePanel(includeStage: true)
          }
        }
        .frame(maxWidth: wide ? 1100 : 570)
        .padding(.horizontal, wide ? 32 : 24)
        .padding(.top, wide ? 27 : 17)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
      }
      .defaultScrollAnchor(.top)
    } primary: { _ in
      foldPane {
        TodayHeader(theme: theme, date: date)
        ticket
        jokeActions
      }
    } secondary: { _ in
      foldPane {
        explorePanel(includeStage: true)
        TodayCategories(library: library, includesMature: includesMature,
                        theme: theme, openLibrary: openLibrary)
        TodayQuickLaughs(library: library, date: date, excluding: joke,
                         includesMature: includesMature, showOnStage: showOnStage)
      }
    }
  }

  private func foldPane<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16, content: content)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
  }

  private var ticket: some View {
    JokeTicket(joke: joke, isDaily: isDaily, isOnline: onlineJoke != nil,
               addToLibrary: hasUnsavedOnlineJoke ? { savingOnline = joke } : nil,
               theme: theme, isVisible: isVisible, revealCount: revealCount, reveal: reveal)
      .id("joke-ticket")
  }

  private var jokeActions: some View {
    TodayActions(joke: joke, library: library,
                 canShuffle: onlineJoke != nil ? !isLoadingOnline : canShuffle && !isLoadingOnline,
                 shuffle: onlineJoke != nil ? requestOnline : shuffle, isVisible: isVisible,
                 isOnline: onlineJoke != nil, canFavorite: !hasUnsavedOnlineJoke, react: react)
      .overlay(alignment: .bottom) {
        if isLoadingOnline {
          ProgressView("Finding a joke…")
            .padding(10)
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
        }
      }
  }

  private func explorePanel(includeStage: Bool) -> some View {
    ExplorePanel(theme: theme, isDaily: isDaily, showDaily: showDaily,
                 showDiscovery: requestOnline,
                 openFavorites: { openLibrary(.favorites) },
                 playOnStage: includeStage ? { showOnStage(joke, .manual) } : nil)
  }

  private func updateDate() {
    let now = Date()
    if isDaily && !Calendar.current.isDate(date, inSameDayAs: now) { revealed = false }
    date = now
  }

  private func showDaily() {
    date = Date()
    cancelOnlineRequest()
    withAnimation(reduceMotion ? nil : .smooth) {
      shuffledJoke = nil
      onlineJoke = nil
      revealed = false
    }
  }

  private func shuffle() {
    guard let next = library.next(excluding: joke.id, allowsMature: includesMature) else { return }
    withAnimation(reduceMotion ? nil : .smooth) {
      shuffledJoke = next
      onlineJoke = nil
      revealed = false
    }
  }

  private func requestOnline() {
    guard !isLoadingOnline else { return }
    guard includesMature || allowsOnlinePreview else {
      confirmsOnline = true
      return
    }
    isLoadingOnline = true
    onlineRequest += 1
  }

  private func cancelOnlineRequest() {
    isLoadingOnline = false
    onlineRequest = 0
  }

  private func loadOnlineJoke() async {
    do {
      for _ in 0..<3 {
        let candidate = try await OnlineJokes.fetch()
        try Task.checkCancellation()
        guard candidate.id != onlineJoke?.id, !library.hasCopy(of: candidate) else { continue }
        withAnimation(reduceMotion ? nil : .smooth) {
          onlineJoke = candidate
          revealed = false
          isLoadingOnline = false
        }
        return
      }
    } catch {
      guard !Task.isCancelled else { return }
    }
    isLoadingOnline = false
    onlineFailed = true
  }

  private func reveal() {
    withAnimation(reduceMotion ? nil : .snappy) {
      revealed = true
      revealCount += 1
    }
    AccessibilityNotification.Announcement(joke.punchline).post()
  }

  private func react() {
    withAnimation(reduceMotion ? nil : .snappy) {
      library.toggleGroan(joke)
      if library.hasGroaned(joke) { groanCount += 1 }
    }
  }
}

private struct TodayHeader: View {
  var theme: JokeTheme
  var date: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
        .font(.footnote.weight(.semibold))
        .textCase(.uppercase)
        .tracking(1.5)
        .foregroundStyle(theme.accent)
      Text("Dad Jokes")
        .font(.system(.largeTitle, design: .serif).weight(.black))
        .foregroundStyle(.primary)
        .accessibilityAddTraits(.isHeader)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
