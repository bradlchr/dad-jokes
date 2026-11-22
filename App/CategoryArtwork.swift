import SwiftUI

struct CategoryArtwork: View {
  var name: String
  var size: CGFloat = 24

  var body: some View {
    Image(assetName)
      .resizable()
      .renderingMode(.original)
      .scaledToFit()
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }

  private var assetName: String {
    let standard = JokeCatalog.categories.contains { $0.name == name }
    return "Category" + (standard ? name.filter(\.isLetter) : "Custom")
  }
}
