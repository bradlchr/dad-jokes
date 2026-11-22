import Foundation

enum JokeCatalog {
  static let categories = load("Categories", as: [JokeCategory].self) ?? []
  static let jokes = load("Jokes", as: [Joke].self) ?? [fallback]
  static let dailyIDs = load("Daily", as: [String].self) ?? []
  static let dailyURL = URL(string: "dadjokes-comedy://daily")!
  static let fallback = Joke(
    id: "scarecrow",
    setup: "Why did the scarecrow win an award?",
    punchline: "Because he was outstanding in his field.",
    categories: ["Puns"]
  )

  static func daily(on date: Date) -> Joke {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: date)
    let reference = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22)) ?? day
    let days = calendar.dateComponents([.day], from: reference, to: day).day ?? 0
    let deck = [fallback] + dailyIDs.compactMap { id in
      jokes.first { $0.id == id && !$0.isMature }
    }
    return deck[(days % deck.count + deck.count) % deck.count]
  }

  private static func load<T: Decodable>(_ filename: String, as type: T.Type) -> T? {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
          let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}

struct JokeCategory: Codable, Identifiable, Sendable {
  var name: String
  var image: String

  var id: String { name }
}
