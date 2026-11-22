import SwiftUI

struct TodayStageCard: View {
  var play: () -> Void
  private let gold = Color(red: 1, green: 0.84, blue: 0.47)
  private let velvet = Color(red: 0.09, green: 0.04, blue: 0.15)

  var body: some View {
    Button(action: play) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Dad Jokes Live")
          .font(.system(.title2, design: .serif).weight(.heavy))
          .foregroundStyle(gold)
          .padding(.horizontal, 18)
          .padding(.top, 16)
        StageSet(performer: .martin, reaction: 0, speaking: false)
          .frame(height: 205)
          .accessibilityHidden(true)
        Label("Play this joke on stage", systemImage: "play.fill")
          .font(.subheadline.weight(.bold))
          .foregroundStyle(velvet)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          .padding(.horizontal, 14)
          .background(gold, in: .rect(cornerRadius: 12))
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(velvet, in: .rect(cornerRadius: 22))
      .clipShape(.rect(cornerRadius: 22))
      .contentShape(.rect(cornerRadius: 22))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Play this joke on stage")
  }
}
