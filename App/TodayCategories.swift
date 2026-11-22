import SwiftUI

struct TodayCategories: View {
  var library: JokeLibrary
  var includesMature: Bool
  var theme: JokeTheme
  var openLibrary: (LibraryFilter) -> Void

  private var featured: [FeaturedCategory] {
    var counts: [String: Int] = [:]
    for joke in library.jokes where includesMature || !joke.isMature {
      for category in Set(joke.categories) { counts[category, default: 0] += 1 }
    }
    let categories = library.categories
    let preferred = ["Puns", "Animal", "Food", "One-Liners", "Science", "Work"]
      .compactMap { name in categories.first { $0.name == name } }
    let preferredNames = Set(preferred.map(\.name))
    let ordered = preferred + categories.filter { !preferredNames.contains($0.name) }
    return Array(ordered.compactMap { category in
      counts[category.name].map { FeaturedCategory(category: category, count: $0) }
    }.prefix(6))
  }

  var body: some View {
    let shelves = featured
    if !shelves.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text("Browse the library")
          .font(.system(.title3, design: .serif).weight(.bold))
          .accessibilityAddTraits(.isHeader)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
          ForEach(shelves) { shelf in
            Button { openLibrary(.category(shelf.category.name)) } label: {
              VStack(alignment: .leading, spacing: 4) {
                CategoryArtwork(name: shelf.category.name, size: 31)
                Text(shelf.category.name).font(.subheadline.weight(.semibold))
                Text("\(shelf.count) jokes").font(.caption).foregroundStyle(.secondary)
              }
              .padding(12)
              .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
              .background(Color("StageSurface"), in: .rect(cornerRadius: 14))
              .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08))
                  .allowsHitTesting(false)
              }
              .contentShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct FeaturedCategory: Identifiable {
  var category: JokeCategory
  var count: Int

  var id: String { category.id }
}
