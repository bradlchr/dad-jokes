import SwiftUI

struct ExplorePanel: View {
  var theme: JokeTheme
  var isDaily: Bool
  var showDaily: () -> Void
  var showDiscovery: () -> Void
  var openFavorites: () -> Void
  var playOnStage: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("More laughs")
        .font(.system(.title3, design: .serif).weight(.bold))
        .accessibilityAddTraits(.isHeader)
      VStack(spacing: 0) {
        if !isDaily {
          ExploreRow(title: "Back to today’s joke", symbol: "sun.max.fill", theme: theme,
                     action: showDaily)
          Divider().padding(.leading, 62)
        }
        if let playOnStage {
          ExploreRow(title: "Play this joke on stage", symbol: "theatermasks", theme: theme,
                     action: playOnStage)
          Divider().padding(.leading, 62)
        }
        ExploreRow(title: "Discover online", symbol: "globe", theme: theme,
                   action: showDiscovery)
        Divider().padding(.leading, 62)
        ExploreRow(title: "Your favorites", symbol: "heart.fill", theme: theme,
                   action: openFavorites)
      }
      .background(Color("StageSurface"), in: .rect(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .strokeBorder(.primary.opacity(0.08))
          .allowsHitTesting(false)
      }
    }
  }
}

private struct ExploreRow: View {
  var title: LocalizedStringKey
  var symbol: String
  var theme: JokeTheme
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: symbol)
          .font(.body.weight(.semibold))
          .foregroundStyle(theme.accent)
          .frame(width: 36, height: 36)
          .background(theme.accent.opacity(0.10), in: .rect(cornerRadius: 10))
          .accessibilityHidden(true)
        Text(title)
          .font(.subheadline.weight(.semibold))
        Spacer(minLength: 5)
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      .foregroundStyle(.primary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 13)
      .padding(.vertical, 9)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
