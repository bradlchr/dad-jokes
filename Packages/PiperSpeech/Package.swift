// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PiperSpeech",
  platforms: [.iOS("26.0"), .macOS("26.0")],
  products: [.library(name: "PiperSpeech", targets: ["PiperSpeech"])],
  targets: [
    .binaryTarget(name: "SherpaOnnxC", path: "SherpaOnnxC-2.0.1.xcframework.zip"),
    .target(name: "PiperSpeech", dependencies: ["SherpaOnnxC"])
  ]
)
