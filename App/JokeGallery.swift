import SwiftUI

struct JokeGallery: View {
  var jokes: [Joke]
  var library: JokeLibrary
  var heading: String
  var showOnStage: (Joke, StagePlayback) -> Void
  var allowsReordering = false
  var sort: LibrarySort?

  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.layoutDirection) private var layoutDirection
  @ScaledMetric(relativeTo: .body) private var columnMinimum = 145.0
  @State private var columns = JokeGalleryColumns(width: 0, minimum: 145, spacing: 12)
  @State private var revealedIDs: Set<String> = []
  @State private var editor: EditDestination?
  @State private var deletion: Joke?

  private static let spacing: CGFloat = 12

  private var rows: [JokeTileRow] {
    let count = columns.tiles.count
    return stride(from: 0, to: jokes.count, by: count).map { index in
      JokeTileRow(id: jokes[index].id, jokes: jokes[index..<min(index + count, jokes.count)])
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          JokeGalleryHeading(title: heading, sort: sort)
          Spacer(minLength: 0)
          Text(jokes.count, format: .number)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("\(jokes.count) jokes"))
        }
        .frame(maxWidth: columns.headingWidth, alignment: .leading)
        if allowsReordering {
          manualGrid
        } else {
          LazyVStack(spacing: Self.spacing) {
            ForEach(rows) { row in
              JokeTileRowLayout(columns: columns, direction: layoutDirection) {
                ForEach(row.jokes) { joke in
                  tile(joke)
                }
              }
            }
          }
        }
      }
      .frame(maxWidth: 1160, alignment: .leading)
      .onGeometryChange(for: JokeGalleryColumns.self) { geometry in
        let fold = FoldDivision.insets(in: geometry)
        return JokeGalleryColumns(width: geometry.size.width,
                                  minimum: typeSize.isAccessibilitySize ? geometry.size.width : columnMinimum,
                                  spacing: Self.spacing,
                                  fold: fold?.dividesHorizontally == true ? fold?.frame : nil)
      } action: { columns = $0 }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 28)
      .frame(maxWidth: .infinity)
    }
    .sheet(item: $editor) { destination in
      switch destination {
      case .joke(let joke):
        JokeEditor(joke: joke, library: library, existing: true)
      case .categories(let joke):
        JokeCategoryEditor(joke: joke, library: library)
      }
    }
    .alert("Delete this joke?", isPresented: Binding(
      get: { deletion != nil }, set: { if !$0 { deletion = nil } }
    ), presenting: deletion) { joke in
      Button("Delete Joke", role: .destructive) {
        revealedIDs.remove(joke.id)
        library.delete(joke)
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  @ViewBuilder
  private var manualGrid: some View {
    let count = columns.headingWidth == nil ? columns.tiles.count : 1
    let items = Array(repeating: GridItem(.flexible(minimum: 0), spacing: Self.spacing), count: count)
    Group {
      if #available(iOS 27.0, macOS 27.0, *) {
        LazyVGrid(columns: items, spacing: Self.spacing) {
          ForEach(jokes) { joke in
            tile(joke)
          }
          .reorderable()
        }
        .reorderContainer(for: Joke.self) { difference in
          let sources = Set(difference.sources)
          var order = jokes.map(\.id)
          let moved = order.filter { sources.contains($0) }
          order.removeAll { sources.contains($0) }
          switch difference.destination.position {
          case .before(let id):
            guard let index = order.firstIndex(of: id) else { return }
            order.insert(contentsOf: moved, at: index)
          case .end:
            order.append(contentsOf: moved)
          }
          library.saveManualOrder(order)
        }
      } else {
        LazyVGrid(columns: items, spacing: Self.spacing) {
          ForEach(jokes) { joke in
            tile(joke)
          }
        }
      }
    }
    .frame(maxWidth: columns.headingWidth, alignment: .leading)
  }

  private func move(_ joke: Joke, by offset: Int) {
    var order = jokes.map(\.id)
    guard let index = order.firstIndex(of: joke.id), order.indices.contains(index + offset) else { return }
    order.swapAt(index, index + offset)
    library.saveManualOrder(order)
  }

  private func tile(_ joke: Joke) -> some View {
    JokeTile(joke: joke, isFavorite: library.isFavorite(joke), revealed: Binding(
      get: { revealedIDs.contains(joke.id) },
      set: { flipped in
        if flipped { revealedIDs.insert(joke.id) } else { revealedIDs.remove(joke.id) }
      }
    ), playOnStage: { showOnStage(joke, .autoplay) }) {
      Button("Edit Joke", systemImage: "pencil") { editor = .joke(joke) }
      Button(library.isFavorite(joke) ? "Remove Favorite" : "Add to Favorites",
             systemImage: library.isFavorite(joke) ? "heart.slash" : "heart") {
        library.toggleFavorite(joke)
      }
      Button("Add to a Category", systemImage: "tag") { editor = .categories(joke) }
      Button("Play on Stage", systemImage: "theatermasks") { showOnStage(joke, .manual) }
      Menu("Share", systemImage: "square.and.arrow.up") {
        JokeShareOptions(joke: joke)
      }
      if allowsReordering {
        Divider()
        Button("Move Earlier", systemImage: "arrow.up") { move(joke, by: -1) }
          .disabled(joke.id == jokes.first?.id)
        Button("Move Later", systemImage: "arrow.down") { move(joke, by: 1) }
          .disabled(joke.id == jokes.last?.id)
      }
      Divider()
      Button("Delete Joke", systemImage: "trash", role: .destructive) { deletion = joke }
    }
  }

  private enum EditDestination: Identifiable {
    case joke(Joke)
    case categories(Joke)

    var id: String {
      switch self {
      case .joke(let joke): "edit-\(joke.id)"
      case .categories(let joke): "categories-\(joke.id)"
      }
    }
  }
}

private struct JokeTileRow: Identifiable {
  var id: String
  var jokes: ArraySlice<Joke>
}

private struct JokeTileRowLayout: Layout {
  var columns: JokeGalleryColumns
  var direction: LayoutDirection

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let height = zip(subviews, columns.tiles).map { tile, column in
      tile.sizeThatFits(ProposedViewSize(width: column.width, height: nil)).height
    }.max() ?? 0
    return CGSize(width: proposal.width ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                     subviews: Subviews, cache: inout ()) {
    for (tile, column) in zip(subviews, columns.tiles) {
      let x = direction == .leftToRight ? bounds.minX + column.offset
        : bounds.maxX - column.offset - column.width
      tile.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                 proposal: ProposedViewSize(width: column.width, height: bounds.height))
    }
  }
}

private struct JokeGalleryColumns: Equatable {
  var tiles: [Column]
  var headingWidth: CGFloat?

  init(width: CGFloat, minimum: CGFloat, spacing: CGFloat, fold: CGRect? = nil) {
    func columns(start: CGFloat, width: CGFloat, limit: Int) -> [Column] {
      let capacity = Int((width + spacing) / (minimum + spacing))
      let count = max(1, min(limit, capacity))
      let tileWidth = max(0, (width - CGFloat(count - 1) * spacing) / CGFloat(count))
      return (0..<count).map { Column(offset: start + CGFloat($0) * (tileWidth + spacing), width: tileWidth) }
    }

    if let fold {
      let leading = max(0, fold.minX - spacing / 2)
      let trailingStart = min(width, fold.maxX + spacing / 2)
      headingWidth = leading
      tiles = columns(start: 0, width: leading, limit: 3)
        + columns(start: trailingStart, width: width - trailingStart, limit: 3)
    } else {
      tiles = columns(start: 0, width: width, limit: 6)
    }
  }

  struct Column: Equatable {
    var offset: CGFloat
    var width: CGFloat
  }
}
