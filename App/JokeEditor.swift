import ImagePlayground
import SwiftUI

struct JokeEditor: View {
  var library: JokeLibrary
  var existing: Bool
  @State private var joke: Joke
  @State private var showsCategories = false
  @State private var drawsArtwork = false
  @State private var artworkError = false
  @Environment(\.supportsImagePlayground) private var supportsImagePlayground
  @Environment(\.dismiss) private var dismiss

  init(joke: Joke, library: JokeLibrary, existing: Bool) {
    _joke = State(initialValue: joke)
    self.library = library
    self.existing = existing
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("The joke") {
          TextField("Setup or one-liner", text: $joke.setup, axis: .vertical)
            .lineLimit(2...8)
          TextField("Punchline (optional)", text: $joke.punchline, axis: .vertical)
            .lineLimit(1...6)
        }
        Section {
          if let image = JokeArtwork.image(from: joke.artwork) {
            Image(decorative: image, scale: 1)
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: 160)
              .accessibilityLabel("Joke illustration")
          }
          Button(joke.artwork == nil ? "Create Cartoon" : "Replace Cartoon", systemImage: "sparkles") {
            drawsArtwork = true
          }
          .disabled(!supportsImagePlayground || joke.setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          if joke.artwork != nil {
            Button("Remove Image", systemImage: "trash", role: .destructive) { joke.artwork = nil }
          }
        } header: {
          Text("Card Artwork")
        } footer: {
          Text(supportsImagePlayground
               ? "Create a cartoon from your joke with Image Playground."
               : "Image Playground is unavailable on this device right now.")
        }
        Section("Audience") {
          Toggle("Mature joke", isOn: $joke.isMature)
        }
        Section {
          DisclosureGroup(isExpanded: $showsCategories) {
            JokeCategoryFields(categories: library.categories, selected: $joke.categories)
          } label: {
            LabeledContent {
              if !joke.categories.isEmpty {
                Text(joke.categories.formatted(.list(type: .and)))
                  .foregroundStyle(.secondary)
              }
            } label: {
              Text("Categories")
            }
          }
        }
        if existing {
          Section {
            Menu("Share Joke", systemImage: "square.and.arrow.up") {
              JokeShareOptions(joke: joke)
            }
          }
        }
      }
      .formStyle(.grouped)
      .imagePlaygroundSheet(isPresented: $drawsArtwork, concepts: [
        .text(String(localized: "A playful cartoon illustration without text or lettering. Inspired by this dad joke:")),
        .text(String(joke.text.prefix(500)))
      ], onCompletion: useArtwork)
      .imagePlaygroundGenerationStyle(.illustration, in: [.illustration])
      .alert("Couldn’t Add the Image", isPresented: $artworkError) {
        Button("OK", role: .cancel) {}
      } message: { Text("Try creating another image in Image Playground.") }
      .navigationTitle(existing ? "Edit joke" : "Add joke")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            joke.setup = joke.setup.trimmingCharacters(in: .whitespacesAndNewlines)
            joke.punchline = joke.punchline.trimmingCharacters(in: .whitespacesAndNewlines)
            library.save(joke)
            dismiss()
          }
          .disabled(joke.setup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .keyboardShortcut(.defaultAction)
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 470, minHeight: 540)
    #endif
  }

  private func useArtwork(_ url: URL) {
    do { joke.artwork = try JokeArtwork.prepare(from: url) }
    catch { artworkError = true }
  }
}
