import AVFoundation
import os
import PiperSpeech

final class StageSpeechAudioUnit: AVSpeechSynthesisProviderAudioUnit {
  private let state = OSAllocatedUnfairLock(initialState: RenderState())
  private let engine = OSAllocatedUnfairLock<PiperEngine?>(initialState: nil)
  private var buses: AUAudioUnitBusArray!
  private var scratch: UnsafeMutablePointer<Float>?

  override init(componentDescription: AudioComponentDescription,
                options: AudioComponentInstantiationOptions = []) throws {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(PiperEngine.sampleRate), channels: 1) else {
      throw CocoaError(.coderInvalidValue)
    }
    let bus = try AUAudioUnitBus(format: format)
    try super.init(componentDescription: componentDescription, options: options)
    buses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [bus])
  }

  override var outputBusses: AUAudioUnitBusArray { buses }

  override var speechVoices: [AVSpeechSynthesisProviderVoice] {
    get {
      PiperStageVoice.allCases.map { voice in
        AVSpeechSynthesisProviderVoice(name: "\(voice.rawValue) (Dad Jokes)", identifier: voice.identifier,
                                       primaryLanguages: ["en-US"], supportedLanguages: ["en-US"])
      }
    }
    set {}
  }

  override func allocateRenderResources() throws {
    try super.allocateRenderResources()
    scratch = .allocate(capacity: Int(maximumFramesToRender))
  }

  override func deallocateRenderResources() {
    scratch?.deallocate()
    scratch = nil
    super.deallocateRenderResources()
  }

  override func synthesizeSpeechRequest(_ request: AVSpeechSynthesisProviderRequest) {
    let generation = state.withLock { value in
      value.generation &+= 1
      value.samples = []
      value.offset = 0
      value.isPreparing = true
      return value.generation
    }

    let voice = PiperStageVoice.allCases.first { $0.identifier == request.voice.identifier }
    let delivery = SpeechMarkup.parse(request.ssmlRepresentation)
    let samples: [Float]
    if let voice, !delivery.text.isEmpty {
      let synthesizer = engine.withLock { engine in
        if engine == nil { engine = PiperEngine(in: Bundle(for: StageSpeechAudioUnit.self)) }
        return engine
      }
      samples = synthesizer?.synthesize(delivery.text, as: voice, pace: delivery.pace) ?? []
    } else {
      samples = []
    }
    state.withLock { value in
      guard generation == value.generation else { return }
      value.samples = samples
      value.isPreparing = false
    }
  }

  override func cancelSpeechRequest() {
    state.withLock { value in
      value = RenderState(generation: value.generation &+ 1)
    }
  }

  override var internalRenderBlock: AUInternalRenderBlock {
    { [unowned self] flags, _, frames, _, audio, _, _ in
      guard frames <= maximumFramesToRender else { return kAudioUnitErr_TooManyFramesToProcess }
      let buffers = UnsafeMutableAudioBufferListPointer(audio)
      guard buffers.count == 1, let scratch else { return kAudioUnitErr_InvalidPropertyValue }
      var buffer = buffers[0]
      let destination = buffer.mData?.assumingMemoryBound(to: Float.self) ?? scratch
      let frameCount = Int(frames)
      guard buffer.mData == nil || Int(buffer.mDataByteSize) >= frameCount * MemoryLayout<Float>.stride else {
        return kAudioUnitErr_InvalidPropertyValue
      }
      buffer.mData = UnsafeMutableRawPointer(destination)
      buffer.mDataByteSize = frames * UInt32(MemoryLayout<Float>.stride)
      buffers[0] = buffer
      // The host's buffer pointers stay on this render thread and this closure runs synchronously.
      let rendered = state.withLockIfAvailableUnchecked { value -> Int in
        let count = min(frameCount, value.samples.count - value.offset)
        if count > 0 {
          value.samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
              destination.update(from: base + value.offset, count: count)
            }
          }
          value.offset += count
        }
        if !value.isPreparing && value.offset == value.samples.count {
          flags.pointee.insert(.offlineUnitRenderAction_Complete)
        }
        return count
      } ?? 0
      destination.advanced(by: rendered).initialize(repeating: 0, count: frameCount - rendered)
      return noErr
    }
  }
}

private struct RenderState {
  var generation: UInt = 0
  var samples: [Float] = []
  var offset = 0
  var isPreparing = false
}

private final class SpeechMarkup: NSObject, XMLParserDelegate {
  private var plainText = ""
  private var pace: Float?

  static func parse(_ markup: String) -> (text: String, pace: Float) {
    guard markup.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") else {
      return (markup, 1)
    }
    let reader = SpeechMarkup()
    let parser = XMLParser(data: Data(markup.utf8))
    parser.delegate = reader
    return parser.parse() ? (reader.plainText, reader.pace ?? 1) : ("", 1)
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    plainText += string
  }

  func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
              qualifiedName qName: String?, attributes attributeDict: [String: String]) {
    if elementName == "prosody", pace == nil, let rate = attributeDict["rate"],
       rate.hasSuffix("%"), let percent = Float(rate.dropLast()), percent.isFinite {
      pace = percent / 100
    }
    if elementName == "break" || elementName == "p" || elementName == "s" { plainText += " " }
  }
}
