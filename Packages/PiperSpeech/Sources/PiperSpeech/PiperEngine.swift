import Foundation
import NaturalLanguage
import SherpaOnnxC

public final class PiperEngine: @unchecked Sendable {
  public static let sampleRate = 22_050
  private static let wordsPerSegment = 24
  private let engine: OpaquePointer
  private let lexiconPath: String
  private let lock = NSLock()
  private var lexiconWords: Set<String>?

  public init?(in bundle: Bundle? = nil) {
    let app = Bundle.main
    let extensionURL = app.builtInPlugInsURL?.appending(path: "Dad Jokes Voices.appex")
    let resources = bundle ?? extensionURL.flatMap { Bundle(url: $0) } ?? app
    guard let model = resources.path(forResource: "en_US-libritts_r-medium", ofType: "onnx"),
          let lexicon = resources.path(forResource: "lexicon", ofType: "txt"),
          let tokens = resources.path(forResource: "tokens", ofType: "txt") else { return nil }

    let engine = model.withCString { modelPath in
      lexicon.withCString { lexiconPath in
        tokens.withCString { tokensPath in
          "cpu".withCString { provider in
            var config = SherpaOnnxOfflineTtsConfig()
            config.model.vits.model = modelPath
            config.model.vits.lexicon = lexiconPath
            config.model.vits.tokens = tokensPath
            config.model.vits.noise_scale = 0.667
            config.model.vits.noise_scale_w = 0.8
            config.model.vits.length_scale = 1
            config.model.provider = provider
            config.model.num_threads = 2
            config.max_num_sentences = 1
            config.silence_scale = 0.30
            return SherpaOnnxCreateOfflineTts(&config)
          }
        }
      }
    }

    guard let engine else { return nil }
    guard SherpaOnnxOfflineTtsSampleRate(engine) == Self.sampleRate else {
      SherpaOnnxDestroyOfflineTts(engine)
      return nil
    }
    self.engine = engine
    self.lexiconPath = lexicon
  }

  deinit {
    SherpaOnnxDestroyOfflineTts(engine)
  }

  public func synthesize(_ text: String, as voice: PiperStageVoice, pace: Float = 1,
                         requiresKnownWords: Bool = false) -> [Float] {
    let input = text.replacingOccurrences(of: "’", with: "'")
      .replacingOccurrences(of: "…", with: "...")
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
    let phrases = input.replacingOccurrences(of: "—", with: "...")
      .replacingOccurrences(of: " -- ", with: "...")
      .components(separatedBy: "...")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let clauses = phrases.enumerated().flatMap { index, phrase in
      let tokenizer = NLTokenizer(unit: .sentence)
      tokenizer.string = phrase
      let sentences = tokenizer.tokens(for: phrase.startIndex..<phrase.endIndex)
        .map { String(phrase[$0]).trimmingCharacters(in: .whitespacesAndNewlines) }
      let lines = (sentences.isEmpty ? [phrase] : sentences).flatMap(Self.boundedSegments)
      return lines.enumerated().map { sentenceIndex, sentence in
        (text: sentence, followsBeat: index > 0 && sentenceIndex == 0)
      }
    }

    return lock.withLock {
      if requiresKnownWords && !recognizesWords(in: input) { return [] }
      let speed = voice.speed * min(max(pace, 0.75), 1.25)
      guard clauses.count > 1 else { return generate(input, as: voice, speed: speed) }

      let pause = Int(voice.clausePause * Double(Self.sampleRate))
      var result: [Float] = []
      for (index, clause) in clauses.enumerated() {
        let last = index == clauses.count - 1
        let line = !last && clause.text.last?.isLetter == true ? clause.text + "," : clause.text
        let samples = generate(line, as: voice, speed: speed * (last ? 0.94 : 1))
        guard !samples.isEmpty else {
          return requiresKnownWords ? [] : generate(input, as: voice, speed: speed)
        }
        if index > 0 {
          let separation = clause.followsBeat ? pause : Self.sampleRate / 7
          result.append(contentsOf: repeatElement(0, count: separation))
        }
        result.append(contentsOf: samples)
      }
      return result
    }
  }

  private static func boundedSegments(_ line: String) -> [String] {
    let words = line.split(whereSeparator: \.isWhitespace)
    guard words.count > wordsPerSegment else { return [line] }
    return stride(from: 0, to: words.count, by: wordsPerSegment).map { start in
      words[start..<min(start + wordsPerSegment, words.count)].joined(separator: " ")
    }
  }

  private func recognizesWords(in text: String) -> Bool {
    if lexiconWords == nil {
      guard let lexicon = try? String(contentsOfFile: lexiconPath, encoding: .utf8) else { return false }
      lexiconWords = Set(lexicon.split(whereSeparator: \.isNewline).compactMap { entry in
        guard let separator = entry.range(of: " || ") else { return nil }
        return String(entry[..<separator.lowerBound])
      })
    }
    guard let lexiconWords else { return false }
    let words = text.lowercased().split { !$0.isLetter && !$0.isNumber && $0 != "'" }
    return words.allSatisfy { word in
      let unquoted = word.trimmingCharacters(in: CharacterSet(charactersIn: "'"))
      return unquoted.isEmpty || lexiconWords.contains(String(word)) || lexiconWords.contains(unquoted)
    }
  }

  private func generate(_ input: String, as voice: PiperStageVoice, speed: Float) -> [Float] {
    var config = SherpaOnnxGenerationConfig()
    config.speed = speed
    config.sid = voice.speaker
    config.silence_scale = 0.30
    guard let audio = SherpaOnnxOfflineTtsGenerateWithConfig(engine, input, &config, nil, nil) else { return [] }
    defer { SherpaOnnxDestroyOfflineTtsGeneratedAudio(audio) }
    guard audio.pointee.n > 0, let samples = audio.pointee.samples else { return [] }
    return Array(UnsafeBufferPointer(start: samples, count: Int(audio.pointee.n)))
  }
}
