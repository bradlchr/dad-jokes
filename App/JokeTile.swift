import SwiftUI

struct JokeTile<Actions: View>: View {
  var joke: Joke
  var isFavorite: Bool
  @Binding var revealed: Bool
  var playOnStage: () -> Void
  @ViewBuilder var actions: () -> Actions

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .body) private var minimumHeight = 174.0

  private var palette: TilePalette {
    let index = joke.id.utf8.reduce(0) { ($0 + Int($1)) % TilePalette.swatches.count }
    return TilePalette.swatches[index]
  }

  var body: some View {
    let artwork = JokeArtwork.image(from: joke.artwork)
    let ink = revealed || artwork != nil ? Color.white : palette.ink
    ZStack(alignment: .topTrailing) {
      if joke.hasPunchline {
        Button(action: flip) {
          faces(artwork: artwork)
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
          Button(action: flip) {
            Text(revealed ? joke.punchline : joke.setup)
          }
          .accessibilityValue(isFavorite ? String(localized: "Favorite") : "")
          .accessibilityHint(revealed ? "Flip to the setup" : "Flip to reveal the punchline")
        }
      } else {
        faces(artwork: artwork)
          .accessibilityRepresentation {
            Text(joke.setup)
              .accessibilityValue(isFavorite ? String(localized: "Favorite") : "")
          }
      }
      Menu(content: actions) {
        Label("Joke actions", systemImage: "ellipsis")
          .labelStyle(.iconOnly)
          .font(.subheadline.weight(.semibold))
          .frame(width: 42, height: 42)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .foregroundStyle(ink)
      .padding(2)
    }
    .overlay(alignment: .bottomTrailing) {
      Button(action: playOnStage) {
        Label("Play on Stage", systemImage: "play.fill")
          .labelStyle(.iconOnly)
          .font(.caption.weight(.bold))
          .frame(width: 29, height: 29)
          .background(ink.opacity(0.15), in: Circle())
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .foregroundStyle(ink)
      .help("Play on Stage")
      .padding(3)
    }
    #if os(iOS)
    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 19))
    #endif
    .contextMenu(menuItems: actions)
    .onChange(of: joke.text) { revealed = false }
  }

  private func faces(artwork: CGImage?) -> some View {
    EqualTileFaces {
      face(back: false, artwork: artwork)
        .accessibilityHidden(revealed)
        .modifier(TileFaceRotation(angle: revealed ? 180 : 0))
      if joke.hasPunchline {
        face(back: true, artwork: artwork)
          .accessibilityHidden(!revealed)
          .modifier(TileFaceRotation(angle: revealed ? 0 : -180))
      }
    }
    .contentShape(.rect(cornerRadius: 19))
  }

  private func face(back: Bool, artwork: CGImage?) -> some View {
    let lightText = back || artwork != nil
    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 5) {
        if isFavorite {
          Image(systemName: "heart.fill")
        }
        Text(back ? String(localized: "Punchline") : joke.categories.first ?? String(localized: "Dad joke"))
          .lineLimit(1)
          .truncationMode(.tail)
      }
      .font(.caption.weight(.bold))
      .padding(.trailing, 28)

      Text(back ? joke.punchline : joke.setup)
        .font(.system(.body, design: .serif).weight(.bold))
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)

      Group {
        if joke.hasPunchline {
          Label(back ? "Flip back" : "Flip to reveal", systemImage: "arrow.trianglehead.clockwise.rotate.90")
            .font(.caption2.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background((lightText ? Color.white : palette.ink).opacity(0.13), in: Capsule())
        } else {
          Text("One-liner")
            .font(.caption2.weight(.semibold))
        }
      }
      .padding(.trailing, 34)
      .frame(minHeight: 26)
    }
    .padding(12)
    .frame(maxWidth: .infinity, minHeight: minimumHeight, maxHeight: .infinity, alignment: .topLeading)
    .foregroundStyle(lightText ? .white : palette.ink)
    .background {
      if let artwork {
        JokeArtworkBackground(image: artwork, ink: palette.ink)
      } else {
        back ? palette.ink : palette.paper
      }
    }
    .clipShape(.rect(cornerRadius: 19))
  }

  private func flip() {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.44)) {
      revealed.toggle()
    }
  }
}

private struct EqualTileFaces: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) }
    return CGSize(width: proposal.width ?? sizes.map(\.width).max() ?? 0,
                  height: max(proposal.height ?? 0, sizes.map(\.height).max() ?? 0))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                     subviews: Subviews, cache: inout ()) {
    for face in subviews {
      face.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
  }
}

@Animatable
private struct TileFaceRotation: ViewModifier {
  var angle: Double

  func body(content: Content) -> some View {
    content
      .opacity(abs(angle) < 90 ? 1 : 0)
      .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
  }
}

private struct TilePalette {
  var paper: Color
  var ink: Color

  static let swatches: [Self] = [
    .init(paper: Color(red: 1, green: 0.88, blue: 0.58), ink: Color(red: 0.26, green: 0.15, blue: 0.31)),
    .init(paper: Color(red: 0.88, green: 0.82, blue: 0.98), ink: Color(red: 0.24, green: 0.16, blue: 0.42)),
    .init(paper: Color(red: 0.76, green: 0.92, blue: 0.84), ink: Color(red: 0.10, green: 0.25, blue: 0.21)),
    .init(paper: Color(red: 1, green: 0.84, blue: 0.82), ink: Color(red: 0.38, green: 0.16, blue: 0.23))
  ]
}
