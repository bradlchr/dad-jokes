import SwiftUI

enum JokeTheme: String, CaseIterable, Identifiable {
  case plum, lagoon, cherry

  var id: Self { self }

  var name: LocalizedStringKey {
    switch self {
    case .plum: "Plum"
    case .lagoon: "Lagoon"
    case .cherry: "Cherry"
    }
  }

  var accent: Color {
    switch self {
    case .plum: Color("AccentColor")
    case .lagoon: Color("Lagoon")
    case .cherry: Color("Cherry")
    }
  }

  var paper: Color {
    switch self {
    case .plum: Color(red: 1, green: 0.85, blue: 0.47)
    case .lagoon: Color(red: 0.69, green: 0.93, blue: 0.82)
    case .cherry: Color(red: 1, green: 0.76, blue: 0.79)
    }
  }

  var ink: Color {
    switch self {
    case .plum: Color(red: 0.17, green: 0.10, blue: 0.31)
    case .lagoon: Color(red: 0.06, green: 0.25, blue: 0.22)
    case .cherry: Color(red: 0.33, green: 0.09, blue: 0.18)
    }
  }
}
