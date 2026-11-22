import SwiftUI

struct JokeCategoryEditor: View {
  var joke: Joke
  var library: JokeLibrary
  @State private var selected: [String]
  @Environment(\.dismiss) private var dismiss

  init(joke: Joke, library: JokeLibrary) {
    self.joke = joke
    self.library = library
    _selected = State(initialValue: joke.categories)
  }

  var body: some View {
    NavigationStack {
      Form {
        JokeCategoryFields(categories: library.categories, selected: $selected)
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
              library.save(latest)
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
  var categories: [JokeCategory]
  @Binding var selected: [String]
  @State private var newCategory = ""

  private var categoryName: String {
    newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var choices: [JokeCategory] {
    categories + selected.filter { name in
      !categories.contains { $0.name == name }
    }.map { JokeCategory(name: $0, image: "tag") }
  }

  var body: some View {
    HStack {
      TextField("New category", text: $newCategory)
        .onSubmit(addCategory)
      Button("Add category", systemImage: "plus", action: addCategory)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .disabled(categoryName.isEmpty || categoryName.caseInsensitiveCompare("Favorites") == .orderedSame)
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
        Label { Text(category.name) } icon: { CategoryArtwork(name: category.name) }
      }
    }
  }

  private func addCategory() {
    guard !categoryName.isEmpty,
          categoryName.caseInsensitiveCompare("Favorites") != .orderedSame else { return }
    let name = categories.first {
      $0.name.caseInsensitiveCompare(categoryName) == .orderedSame
    }?.name ?? categoryName
    if !selected.contains(name) { selected.append(name) }
    newCategory = ""
  }
}
