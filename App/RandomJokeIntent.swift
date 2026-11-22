import AppIntents
import Foundation

struct RandomJokeIntent: AppIntent {
  static let title: LocalizedStringResource = "Tell Me a Dad Joke"
  static let description = IntentDescription("Get a random joke from your Dad Jokes library.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let allowsMature = UserDefaults.standard.bool(forKey: "include-mature-jokes")
    let jokes = JokeLibrary.loadArchive().jokes.filter { allowsMature || !$0.isMature }
    let joke = jokes.randomElement() ?? JokeCatalog.daily(on: Date())
    return .result(value: joke.text, dialog: "\(joke.text)")
  }
}

struct DadJokesShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RandomJokeIntent(),
      phrases: ["Tell me a joke with \(.applicationName)"],
      shortTitle: "Tell Me a Dad Joke",
      systemImageName: "mustache.fill"
    )
  }
}
