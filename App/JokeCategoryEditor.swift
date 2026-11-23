import SwiftUI

struct JokeCategoryEditor: View {
  var joke: Joke
  var library: JokeLibrary
  @State private var selected: [String]
  @State private var categoryDrafts: [String: Data?] = [:]
  @Environment(\.dismiss) private var dismiss

  init(joke: Joke, library: JokeLibrary) {
    self.joke = joke
    self.library = library
    _selected = State(initialValue: joke.categories)
  }

  var body: some View {
    NavigationStack {
      Form {
        JokeCategoryFields(library: library, selected: $selected, categoryDrafts: $categoryDrafts)
      }
      .formStyle(.grouped)
      .navigationTitle("Categories")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", role: .cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            if var latest = library.jokes.first(where: { $0.id == joke.id }) {
              latest.categories = selected
              library.save(latest, categoryDrafts: categoryDrafts)
            }
            dismiss()
          }
          .keyboardShortcut(.defaultAction)
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 420, minHeight: 460)
    #endif
  }
}

struct JokeCategoryFields: View {
  var library: JokeLibrary
  @Binding var selected: [String]
  @Binding var categoryDrafts: [String: Data?]

  private var choices: [JokeCategory] {
    let categories = library.categories
    let knownNames = Set(categories.map(\.name))
    let drafts = Set(selected).union(categoryDrafts.keys).subtracting(knownNames)
    return categories + drafts.sorted().map { JokeCategory(name: $0, image: "tag") }
  }

  var body: some View {
    NavigationLink {
      CategoryDetailsView(library: library, additionalNames: choices.map(\.name),
                          additionalIcons: categoryDrafts.compactMapValues { $0 }) { name, icon in
        categoryDrafts.updateValue(icon, forKey: name)
        selected.append(name)
      }
    } label: {
      Label("New Category", systemImage: "plus")
    }

    ForEach(choices) { category in
      Toggle(isOn: Binding(
        get: { selected.contains(category.name) },
        set: { enabled in
          if enabled {
            if !selected.contains(category.name) { selected.append(category.name) }
          } else {
            selected.removeAll { $0 == category.name }
          }
        }
      )) {
        Label { Text(category.name) } icon: {
          CategoryArtwork(name: category.name, draftIcon: categoryDrafts[category.name] ?? nil)
        }
      }
    }
  }
}
