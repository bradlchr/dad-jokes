import AVFoundation
import SwiftUI

@main
struct DadJokesApp: App {
  @State private var library = JokeLibrary()
  @Environment(\.scenePhase) private var scenePhase
  #if os(macOS)
  @AppStorage("joke-theme") private var theme: JokeTheme = .plum
  #endif

  var body: some Scene {
    mainWindow
    #if os(macOS)
    Settings {
      NavigationStack {
        PreferencesView(library: library, theme: $theme)
      }
        .environment(\.categoryIcons, library.archive.categoryIcons ?? [:])
        .environment(\.originalCategoryNames, library.originalCategoryNames)
        .tint(theme.accent)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 420, idealHeight: 475)
    }
    #endif
  }

  private var mainWindow: some Scene {
    WindowGroup {
      ContentView(library: library)
        .environment(\.categoryIcons, library.archive.categoryIcons ?? [:])
        .environment(\.originalCategoryNames, library.originalCategoryNames)
        .task { AVSpeechSynthesisProviderVoice.updateSpeechVoices() }
        .task {
          await library.recoverOriginalLibrary()
          library.narrationOptimizer.refresh(for: library)
        }
        .onChange(of: scenePhase, initial: true) {
          if scenePhase == .active { library.narrationOptimizer.refresh(for: library) }
        }
    }
    #if os(macOS)
    .defaultSize(width: 1000, height: 730)
    #endif
  }
}
