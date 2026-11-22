import SwiftUI

struct JokeShareOptions: View {
  var joke: Joke

  var body: some View {
    ShareLink(item: joke.text) {
      Label("Share as Text", systemImage: "text.quote")
    }
    ShareLink(item: SharedJokeFile(joke: joke),
              subject: Text("A joke from Dad Jokes"),
              message: Text("You’ll need the Dad Jokes app to open this .dadjoke attachment. Install or update the app here:\nhttps://apps.apple.com/app/id1540591828"),
              preview: SharePreview("Dad Joke")) {
      Label("Share .dadjoke File", systemImage: "doc")
    }
  }
}
