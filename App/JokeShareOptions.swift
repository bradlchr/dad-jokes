import SwiftUI

struct JokeShareOptions: View {
  var joke: Joke

  var body: some View {
    ShareLink(item: joke.text) {
      Label("Share as Text", systemImage: "text.quote")
    }
    ShareLink(item: SharedJokeFile(joke: joke),
              subject: Text("A joke from Dad Jokes"),
              preview: SharePreview("Dad Joke")) {
      Label("Share .dadjoke File", systemImage: "doc")
    }
  }
}
