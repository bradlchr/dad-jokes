import SwiftUI

struct CategoryArtwork: View {
  var name: String
  var size: CGFloat = 24
  var draftIcon: Data?
  @Environment(\.categoryIcons) private var categoryIcons
  @Environment(\.originalCategoryNames) private var originalCategoryNames

  var body: some View {
    Group {
      if let icon = JokeArtwork.image(from: draftIcon ?? categoryIcons[name]) {
        Image(decorative: icon, scale: CGFloat(max(icon.width, icon.height)) / size)
          .resizable()
          .renderingMode(.original)
          .scaledToFill()
          .frame(width: size, height: size)
          .clipShape(.rect(cornerRadius: size / 4))
      } else {
        Image(Self.assetName(for: originalCategoryNames[name] ?? name))
          .resizable()
          .renderingMode(.original)
          .scaledToFit()
          .frame(width: size, height: size)
      }
    }
    .accessibilityHidden(true)
  }
  static func assetName(for name: String) -> String {
    let standard = JokeCatalog.categories.contains { $0.name == name }
    return "Category" + (standard ? name.filter(\.isLetter) : "Custom")
  }
}

extension EnvironmentValues {
  @Entry var categoryIcons: [String: Data] = [:]
  @Entry var originalCategoryNames: [String: String] = [:]
}
