import AVFoundation
import NaturalLanguage
import PiperSpeech

struct StageVoice {
  var systemVoice: AVSpeechSynthesisVoice?
  var languageTag: String
  var piper: PiperStageVoice?

  var canNarrate: Bool { piper != nil || systemVoice != nil }

  var isHighQuality: Bool {
    piper != nil || (systemVoice.map { $0.quality == .premium || $0.quality == .enhanced } ?? false)
  }

  var languageName: String {
    let code = Locale(identifier: languageTag).language.languageCode?.identifier ?? languageTag
    return Locale.current.localizedString(forLanguageCode: code) ?? code
  }

  static func select(for joke: Joke, performer: StagePerformer) -> Self {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(joke.text)
    let likelyLanguage = recognizer.languageHypotheses(withMaximum: 1)
      .first { $0.value >= 0.55 }?.key.rawValue
    let preferredLanguage = Locale.preferredLanguages.first
    let language = likelyLanguage ?? preferredLanguage.flatMap(languageCode) ?? "en"
    let tag = Locale.preferredLanguages.first { languageCode($0) == language }
      ?? (language == "en" ? "en-US" : language)

    let installed = AVSpeechSynthesisVoice.speechVoices()
    let piper = language == "en" ? PiperStageVoice(rawValue: performer.rawValue) : nil
    let matching = installed.filter { candidate in
      candidate.gender == .male && languageCode(candidate.language) == language
        && !PiperStageVoice.allCases.contains(where: { $0.identifier == candidate.identifier })
        && !candidate.voiceTraits.contains(.isNoveltyVoice)
        && !candidate.voiceTraits.contains(.isPersonalVoice)
    }
    guard let bestQuality = matching.map(\.quality.rawValue).max() else {
      return Self(systemVoice: nil, languageTag: tag, piper: piper)
    }
    let best = matching.filter { $0.quality.rawValue == bestQuality }
    let regional = best.filter { $0.language.caseInsensitiveCompare(tag) == .orderedSame }
    let candidates = (regional.isEmpty ? best : regional).sorted { $0.identifier < $1.identifier }
    return Self(systemVoice: candidates[performer.voiceIndex % candidates.count], languageTag: tag, piper: piper)
  }

  private static func languageCode(_ tag: String) -> String? {
    Locale(identifier: tag).language.languageCode?.identifier
  }
}
