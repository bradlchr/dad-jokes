public enum PiperStageVoice: String, CaseIterable, Sendable {
  case martin = "Martin"
  case ravi = "Ravi"
  case mateo = "Mateo"
  case kenji = "Kenji"

  public var identifier: String {
    "com.mimikmeapps.dadjokes.piper.\(rawValue.lowercased())"
  }

  // LibriTTS-R speaker IDs 17, 922, 580, and 335 in the bundled model's speaker map.
  var speaker: Int32 {
    switch self {
    case .martin: 805
    case .ravi: 5
    case .mateo: 615
    case .kenji: 84
    }
  }

  var speed: Float {
    switch self {
    case .martin: 0.91
    case .ravi: 0.97
    case .mateo: 1.01
    case .kenji: 0.94
    }
  }
  // A beat between clauses marked by a dash or an ellipsis.
  var clausePause: Double {
    switch self {
    case .martin: 0.25
    case .ravi: 0.19
    case .mateo: 0.13
    case .kenji: 0.23
    }
  }
}
