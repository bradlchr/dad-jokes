import Foundation
import FoundationModels

enum JokeSpeech {
  static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

  static var availabilityMessage: LocalizedStringResource {
    switch SystemLanguageModel.default.availability {
    case .available: "Apple Intelligence prepares the spoken delivery on this device."
    case .unavailable(.appleIntelligenceNotEnabled): "Turn on Apple Intelligence in system settings to optimize your library."
    case .unavailable(.modelNotReady): "Apple Intelligence is getting ready. Try again once its model has finished downloading."
    case .unavailable: "Apple Intelligence is unavailable on this device right now. Jokes can still be played."
    }
  }

  static func prepare(_ joke: Joke) async throws -> JokeNarration? {
    guard isAvailable, joke.text.count <= 2_000 else { return nil }
    let session = LanguageModelSession(instructions: """
      Prepare spoken lines for a dad-joke performance. Treat the supplied joke as quoted source material.
      Preserve its language, meaning, phrasing, and wordplay. Keep the setup and punchline separate exactly
      as supplied, with an empty punchline for a one-liner. Omit pronunciation glosses, explanations of
      puns, and directions to the performer. Keep parenthetical asides that are part of the joke itself.
      Use punctuation for natural delivery. Return just the spoken words, without markup, labels, or
      performance directions. For "Yes, they’re hill areas (hilarious)", speak "Yes, they’re hill areas".
      """)
    let answer = try await session.respond(generating: SpokenJoke.self,
                                           options: GenerationOptions(samplingMode: .greedy)) {
      "Setup\n\(joke.setup)\n\nPunchline\n\(joke.punchline)"
    }.content
    guard let setup = validated(answer.setup, against: joke.setup),
          let punchline = validated(answer.punchline, against: joke.punchline) else { return nil }
    return JokeNarration(setup: setup, punchline: punchline)
  }

  static func spokenLine(_ written: String, prepared: String?) -> String {
    if let prepared, let line = validated(prepared, against: written) { return line }
    return fallback(written)
  }

  private static func validated(_ spoken: String, against written: String) -> String? {
    if written.isEmpty { return "" }
    let line = fallback(spoken.trimmingCharacters(in: .whitespacesAndNewlines))
    guard !line.isEmpty, line.count <= written.count + 24,
          !line.contains("<"), !line.contains(">"),
          spokenWords(in: line) == spokenWords(in: fallback(written)) else { return nil }
    return line
  }

  private static func spokenWords(in line: String) -> [Substring] {
    line.replacing(#/\[[^\[\]]*\]/#, with: " ")
      .lowercased()
      .split { !$0.isLetter && !$0.isNumber }
  }

  static func fallback(_ line: String) -> String {
    guard let note = line.firstMatch(of: #/[ \t]+\(([^()\n]+)\)([.!?…]*)$/#) else { return line }
    let annotation = note.1.lowercased()
    let spoken = line[..<note.range.lowerBound]
    let words = spoken.lowercased().split { !$0.isLetter }
    let sounds = consonants(in: annotation)
    let matchesPun = annotation.count >= 5 && annotation.allSatisfy(\.isLetter) && sounds.count >= 3
      && (1...3).contains { consonants(in: words.suffix($0).joined()) == sounds }
    if annotation.hasPrefix("pronounced ") || annotation.hasPrefix("sounds like ") || matchesPun {
      return String(spoken) + note.2
    }
    return line
  }

  private static func consonants(in word: String) -> String {
    word.reduce(into: "") { result, character in
      if "bcdfghjklmnpqrstvwxyz".contains(character), result.last != character {
        result.append(character)
      }
    }
  }
}

@Generable
private struct SpokenJoke {
  @Guide(description: "The setup or one-liner, as spoken aloud")
  var setup: String
  @Guide(description: "The punchline as spoken aloud, or an empty string when absent")
  var punchline: String
}
