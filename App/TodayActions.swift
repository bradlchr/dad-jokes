import SwiftUI

struct TodayActions: View {
  var joke: Joke
  var library: JokeLibrary
  var canShuffle: Bool
  var shuffle: () -> Void
  var isVisible: Bool
  var isOnline: Bool
  var canFavorite: Bool
  var react: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      let layout = dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
        : AnyLayout(HStackLayout(spacing: 10))
      layout {
        Button(action: shuffle) {
          Label(isOnline ? "Another online joke" : "Another joke", systemImage: "shuffle")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 38)
        }
        .disabled(!canShuffle)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        #if os(macOS)
        .keyboardShortcut("j", modifiers: [.command, .shift])
        #endif

        HStack(spacing: 10) {
          if canFavorite {
            Button {
              library.toggleFavorite(joke)
            } label: {
              Label(library.isFavorite(joke) ? "Remove favorite" : "Add to favorites",
                    systemImage: library.isFavorite(joke) ? "heart.fill" : "heart")
                .labelStyle(.iconOnly)
                .frame(width: 37, height: 37)
            }
            .accessibilityAddTraits(library.isFavorite(joke) ? .isSelected : [])
          }
          Menu {
            JokeShareOptions(joke: joke)
          } label: {
            Label("Share joke", systemImage: "square.and.arrow.up")
              .labelStyle(.iconOnly)
              .frame(width: 37, height: 37)
          }
          #if os(macOS)
          .menuIndicator(.hidden)
          #endif
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
      }

      if isVisible {
        Button(action: react) {
          Label(library.hasGroaned(joke) ? "Groan appreciated" : "Give it a groan",
                systemImage: library.hasGroaned(joke) ? "party.popper.fill" : "face.smiling")
            .frame(minHeight: 34)
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(library.hasGroaned(joke) ? .isSelected : [])
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
