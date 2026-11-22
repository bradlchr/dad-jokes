import Foundation

struct JokePerformance: Identifiable {
  var id = UUID()
  var joke: Joke
  var performer: StagePerformer
  var autoplay = false
}

enum StagePlayback {
  case manual, autoplay
}

enum StagePerformer: String, CaseIterable {
  case martin = "Martin"
  case ravi = "Ravi"
  case mateo = "Mateo"
  case kenji = "Kenji"

  static let preferenceKey = "stage-favorite-performer"
  static let randomPreference = "random"

  static func select(preference: String, excluding last: Self? = nil) -> Self {
    if let favorite = Self(rawValue: preference) { return favorite }
    return allCases.filter { $0 != last }.randomElement() ?? .martin
  }

  var image: String { "Stage\(rawValue)" }
  var voiceIndex: Int { Self.allCases.firstIndex(of: self) ?? 0 }

  var punchlineBeat: Duration {
    switch self {
    case .martin: .milliseconds(480)
    case .ravi: .milliseconds(350)
    case .mateo: .milliseconds(220)
    case .kenji: .milliseconds(420)
    }
  }

  var punchlinePace: Float {
    switch self {
    case .martin: 0.91
    case .ravi: 0.96
    case .mateo: 1.04
    case .kenji: 0.93
    }
  }

  var accessibilityDescription: String {
    switch self {
    case .martin: String(localized: "Martin, an older dad with glasses and a gray beard")
    case .ravi: String(localized: "Ravi, a dad wearing a navy turban and marigold kurta")
    case .mateo: String(localized: "Mateo, a dad wearing a coral shirt and using a blue wheelchair")
    case .kenji: String(localized: "Kenji, a dad with silver-streaked hair and a plum jacket")
    }
  }
}
