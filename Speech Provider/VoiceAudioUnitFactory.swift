import CoreAudioKit

public final class VoiceAudioUnitFactory: NSObject, AUAudioUnitFactory {
  public func beginRequest(with context: NSExtensionContext) {}

  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    try StageSpeechAudioUnit(componentDescription: componentDescription)
  }
}
