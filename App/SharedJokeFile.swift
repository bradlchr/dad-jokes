import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
  static let dadJoke = UTType(exportedAs: "com.mimikmeapps.dadjokes.joke", conformingTo: .data)
}

struct SharedJokeFile: Codable, Transferable, Sendable {
  private static let maximumBytes = 256 * 1024

  var version = 1
  var setup: String
  var punchline: String
  var isMature: Bool

  init(joke: Joke) {
    setup = joke.setup
    punchline = joke.punchline
    isMature = joke.isMature
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .dadJoke) { file in
      let data = try JSONEncoder().encode(file)
      guard data.count <= maximumBytes else { throw CocoaError(.fileWriteOutOfSpace) }
      let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let url = directory.appending(path: "Dad Joke.dadjoke")
      try data.write(to: url, options: .atomic)
      return SentTransferredFile(url)
    }
  }

  static func open(_ url: URL) throws -> Joke {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

    var coordinationError: NSError?
    var result: Result<Joke, Error>?
    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { fileURL in
      result = Result {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        guard let data = try handle.read(upToCount: maximumBytes + 1),
              data.count <= maximumBytes else { throw CocoaError(.fileReadCorruptFile) }
        let file = try JSONDecoder().decode(Self.self, from: data)
        let setup = file.setup.trimmingCharacters(in: .whitespacesAndNewlines)
        let punchline = file.punchline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard file.version == 1, !setup.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return Joke(setup: setup, punchline: punchline, isMature: file.isMature)
      }
    }
    if let coordinationError { throw coordinationError }
    guard let result else { throw CocoaError(.fileReadUnknown) }
    return try result.get()
  }
}
