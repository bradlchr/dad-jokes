import Foundation

enum OnlineJokes {
  private struct Response: Decodable {
    var id: String
    var joke: String
  }

  static func fetch() async throws -> Joke {
    var request = URLRequest(url: URL(string: "https://icanhazdadjoke.com/")!)
    request.timeoutInterval = 12
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Dad Jokes (https://apps.apple.com/app/id1540591828)",
                     forHTTPHeaderField: "User-Agent")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }
    let payload = try JSONDecoder().decode(Response.self, from: data)
    let text = payload.joke
      .replacingOccurrences(of: "\\r\\n", with: "\n")
      .replacingOccurrences(of: "\r\\n", with: "\n")
      .replacingOccurrences(of: "\\n", with: "\n")
      .replacingOccurrences(of: "\r\n", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { throw URLError(.cannotDecodeContentData) }
    let parts = Joke.split(text)
    return Joke(id: "online-\(payload.id)", setup: parts.setup, punchline: parts.punchline,
                isMature: true)
  }
}
