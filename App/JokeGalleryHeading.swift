import SwiftUI

struct JokeGalleryHeading: View {
  var title: String
  var sort: LibrarySort?

  var body: some View {
    if let sort {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          heading.fixedSize()
          sortNote(sort).fixedSize()
        }
        VStack(alignment: .leading, spacing: 3) {
          heading
          sortNote(sort)
        }
      }
    } else {
      heading
    }
  }

  private var heading: some View {
    Text(title)
      .font(.system(.title2, design: .serif).weight(.bold))
      .accessibilityAddTraits(.isHeader)
  }

  private func sortNote(_ sort: LibrarySort) -> some View {
    Text(sort.title)
      .font(.caption)
      .foregroundStyle(.secondary)
      .accessibilityLabel("Sort order: \(String(localized: sort.title))")
  }
}
