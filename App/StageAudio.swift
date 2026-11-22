import AVFoundation
import Observation
import OSLog
import PiperSpeech

@MainActor
@Observable
final class StageAudio: NSObject, AVSpeechSynthesizerDelegate {
  private(set) var isSpeaking = false
  private static let logger = Logger(subsystem: "com.mimikmeapps.dadjokes", category: "StageSpeech")

  @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
  @ObservationIgnored private var currentUtterance: ObjectIdentifier?
  @ObservationIgnored private var afterSpeech: (() -> Void)?
  @ObservationIgnored private var audience: AudiencePlayer?
  @ObservationIgnored private var piperTask: Task<Void, Never>?
  @ObservationIgnored private var piperPlaybackID: UUID?
  @ObservationIgnored private var linePlayer: PiperLinePlayer?

  override init() {
    super.init()
    synthesizer.delegate = self
  }

  func speak(_ text: String, using voice: StageVoice, pace: Float, completion: @escaping () -> Void) {
    stop()
    prepareSession()
    if let piper = voice.piper {
      speakWithPiper(text, as: piper, pace: pace, fallback: voice.systemVoice, completion: completion)
    } else if let installed = voice.systemVoice {
      speakWithSystem(text, using: installed, pace: pace, completion: completion)
    } else {
      completion()
    }
  }

  private func speakWithSystem(_ text: String, using voice: AVSpeechSynthesisVoice, pace: Float,
                               completion: @escaping () -> Void) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92 * pace
    utterance.voice = voice
    currentUtterance = ObjectIdentifier(utterance)
    afterSpeech = completion
    isSpeaking = true
    synthesizer.speak(utterance)
  }

  func playAudience() {
    prepareSession()
    if audience == nil { audience = try? AudiencePlayer() }
    try? audience?.play()
  }

  func stop() {
    currentUtterance = nil
    afterSpeech = nil
    piperPlaybackID = nil
    piperTask?.cancel()
    piperTask = nil
    linePlayer?.stop()
    linePlayer = nil
    isSpeaking = false
    synthesizer.stopSpeaking(at: .immediate)
    audience?.stop()
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                     didFinish utterance: AVSpeechUtterance) {
    let id = ObjectIdentifier(utterance)
    Task { @MainActor in
      guard id == currentUtterance else { return }
      let completion = afterSpeech
      afterSpeech = nil
      currentUtterance = nil
      isSpeaking = false
      completion?()
    }
  }

  nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                     didCancel utterance: AVSpeechUtterance) {
    let id = ObjectIdentifier(utterance)
    Task { @MainActor in
      guard id == currentUtterance else { return }
      afterSpeech = nil
      currentUtterance = nil
      isSpeaking = false
    }
  }

  private func speakWithPiper(_ text: String, as voice: PiperStageVoice, pace: Float,
                              fallback: AVSpeechSynthesisVoice?, completion: @escaping () -> Void) {
    let id = UUID()
    let requiresKnownWords = fallback != nil
    piperPlaybackID = id
    isSpeaking = true
    piperTask = Task { [weak self] in
      let samples = await Task.detached(priority: .userInitiated) {
        LocalPiper.engine?.synthesize(text, as: voice, pace: pace, requiresKnownWords: requiresKnownWords) ?? []
      }.value
      guard !Task.isCancelled else { return }
      self?.playPiperLine(samples, id: id, voice: voice, text: text, pace: pace,
                          fallback: fallback, completion: completion)
    }
  }

  private func playPiperLine(_ samples: [Float], id: UUID, voice: PiperStageVoice,
                             text: String, pace: Float, fallback: AVSpeechSynthesisVoice?,
                             completion: @escaping () -> Void) {
    guard piperPlaybackID == id else { return }
    piperTask = nil
    if let player = try? PiperLinePlayer(samples: samples) {
      Self.logger.debug("Playing bundled stage voice: \(voice.identifier, privacy: .public)")
      linePlayer = player
      player.play { [weak self] in
        Task { @MainActor [weak self] in
          guard let self, self.piperPlaybackID == id else { return }
          self.piperPlaybackID = nil
          self.linePlayer = nil
          self.isSpeaking = false
          completion()
        }
      }
    } else {
      Self.logger.info("Bundled stage voice could not read the full line. Checking the installed voice.")
      piperPlaybackID = nil
      isSpeaking = false
      if let fallback {
        speakWithSystem(text, using: fallback, pace: pace, completion: completion)
      } else {
        completion()
      }
    }
  }

  private func prepareSession() {
    #if os(iOS)
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.ambient)
    try? session.setActive(true)
    #endif
  }
}

private final class AudiencePlayer {
  private let file: AVAudioFile
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()

  init() throws {
    guard let url = Bundle.main.url(forResource: "StageAudience", withExtension: "m4a") else {
      throw CocoaError(.fileNoSuchFile)
    }
    file = try AVAudioFile(forReading: url)
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
    player.volume = 0.72
  }

  func play() throws {
    player.stop()
    file.framePosition = 0
    if !engine.isRunning { try engine.start() }
    player.scheduleFile(file, at: nil)
    player.play()
  }

  func stop() {
    player.stop()
    engine.stop()
  }
}

private enum LocalPiper {
  static let engine = PiperEngine()
}

private final class PiperLinePlayer {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let buffer: AVAudioPCMBuffer

  init(samples: [Float]) throws {
    guard !samples.isEmpty, let frames = AVAudioFrameCount(exactly: samples.count),
          let format = AVAudioFormat(standardFormatWithSampleRate: Double(PiperEngine.sampleRate), channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
          let channel = buffer.floatChannelData?[0] else {
      throw CocoaError(.coderInvalidValue)
    }
    buffer.frameLength = frames
    samples.withUnsafeBufferPointer { source in
      if let address = source.baseAddress { channel.update(from: address, count: samples.count) }
    }
    self.buffer = buffer
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    try engine.start()
  }

  func play(completion: @escaping @Sendable () -> Void) {
    player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in completion() }
    player.play()
  }

  func stop() {
    player.stop()
    engine.stop()
  }
}
