import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct CategoryIconPreset: Identifiable, Equatable {
  let id: String
  var name: LocalizedStringResource
  var bundledAssetName: String?

  var assetName: String { bundledAssetName ?? ("CategoryPreset" + id) }

  static var defaults: [Self] {
    JokeCatalog.categories.map {
      let assetName = CategoryArtwork.assetName(for: $0.name)
      return Self(id: assetName, name: LocalizedStringResource(stringLiteral: $0.name), bundledAssetName: assetName)
    }
  }

  @MainActor private static var iconCache: [String: Data] = [:]

  @MainActor
  static func assets(matching icons: Set<Data>) -> Set<String> {
    guard !icons.isEmpty else { return [] }
    return Set((defaults + all).compactMap { preset in
      guard let data = try? preset.iconData(), icons.contains(data) else { return nil }
      return preset.assetName
    })
  }

  static let all: [Self] = [
    Self(id: "Apple", name: "Apple"),
    Self(id: "Banana", name: "Banana"),
    Self(id: "Cherries", name: "Cherries"),
    Self(id: "Avocado", name: "Avocado"),
    Self(id: "Carrot", name: "Carrot"),
    Self(id: "Cookie", name: "Cookie"),
    Self(id: "Doughnut", name: "Doughnut"),
    Self(id: "IceCream", name: "Ice Cream"),
    Self(id: "Cupcake", name: "Cupcake"),
    Self(id: "Popcorn", name: "Popcorn"),
    Self(id: "Coffee", name: "Coffee"),
    Self(id: "Teapot", name: "Teapot"),
    Self(id: "Hamburger", name: "Hamburger"),
    Self(id: "Taco", name: "Taco"),
    Self(id: "Mushroom", name: "Mushroom"),
    Self(id: "Cat", name: "Cat"),
    Self(id: "Dog", name: "Dog"),
    Self(id: "Fox", name: "Fox"),
    Self(id: "Panda", name: "Panda"),
    Self(id: "Owl", name: "Owl"),
    Self(id: "Penguin", name: "Penguin"),
    Self(id: "Whale", name: "Whale"),
    Self(id: "Octopus", name: "Octopus"),
    Self(id: "Butterfly", name: "Butterfly"),
    Self(id: "Bee", name: "Bee"),
    Self(id: "Cactus", name: "Cactus"),
    Self(id: "Sunflower", name: "Sunflower"),
    Self(id: "MapleLeaf", name: "Maple Leaf"),
    Self(id: "Rainbow", name: "Rainbow"),
    Self(id: "Umbrella", name: "Umbrella"),
    Self(id: "Campfire", name: "Campfire"),
    Self(id: "Tent", name: "Tent"),
    Self(id: "Mountain", name: "Mountain"),
    Self(id: "Wave", name: "Wave"),
    Self(id: "Rocket", name: "Rocket"),
    Self(id: "Planet", name: "Planet"),
    Self(id: "Telescope", name: "Telescope"),
    Self(id: "Ghost", name: "Ghost"),
    Self(id: "Pumpkin", name: "Pumpkin"),
    Self(id: "Balloon", name: "Balloon"),
    Self(id: "PartyPopper", name: "Party Popper"),
    Self(id: "Guitar", name: "Guitar"),
    Self(id: "Headphones", name: "Headphones"),
    Self(id: "Camera", name: "Camera"),
    Self(id: "GameController", name: "Game Controller"),
    Self(id: "Dice", name: "Dice"),
    Self(id: "SoccerBall", name: "Soccer Ball"),
    Self(id: "Skateboard", name: "Skateboard"),
    Self(id: "Bicycle", name: "Bicycle"),
    Self(id: "Train", name: "Train"),
    Self(id: "Airplane", name: "Airplane"),
  ]

  @MainActor
  func iconData() throws -> Data {
    if let data = Self.iconCache[assetName] { return data }
    let renderer = ImageRenderer(content:
      Image(assetName)
        .resizable()
        .frame(width: 42, height: 42)
    )
    renderer.scale = 3
    let data = NSMutableData()
    guard let image = renderer.cgImage,
          let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    Self.iconCache[assetName] = data as Data
    return data as Data
  }
}
