import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum JokeArtwork {
  static func prepare(from url: URL, maximumPixelSize: Int = 720) throws -> Data {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
    ] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
      throw CocoaError(.fileReadCorruptFile)
    }

    let encoded = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(encoded, UTType.jpeg.identifier as CFString, 1, nil) else {
      throw CocoaError(.fileWriteUnknown)
    }
    let quality = [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
    CGImageDestinationAddImage(destination, image, quality)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    return encoded as Data
  }

  static func image(from data: Data?) -> CGImage? {
    guard let data, let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 720
    ] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
  }
}

struct JokeArtworkBackground: View {
  var image: CGImage
  var ink: Color

  var body: some View {
    GeometryReader { geometry in
      Image(decorative: image, scale: 1)
        .resizable()
        .scaledToFill()
        .frame(width: geometry.size.width, height: geometry.size.height)
        .clipped()
    }
    .overlay(alignment: .top) {
      LinearGradient(stops: [
        .init(color: ink.opacity(0.89), location: 0),
        .init(color: ink.opacity(0.79), location: 0.50),
        .init(color: Color.black.opacity(0.60), location: 1)
      ], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    .background(ink)
    .accessibilityHidden(true)
  }
}
