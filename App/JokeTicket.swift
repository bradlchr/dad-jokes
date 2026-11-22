import SwiftUI

struct JokeTicket: View {
  var joke: Joke
  var isDaily: Bool
  var isOnline: Bool
  var addToLibrary: (() -> Void)?
  var theme: JokeTheme
  var isVisible: Bool
  var revealCount: Int
  var reveal: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 36.0

  private var paper: Color {
    isOnline ? theme.paper.mix(with: .white, by: 0.58) : theme.paper
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(isOnline ? "From online" : isDaily ? "Joke of the day" : "From your library")
            .font(.caption.weight(.heavy))
            .tracking(1.5)
            .textCase(.uppercase)
          if isOnline {
            Label(addToLibrary == nil ? "Saved to your library" : "Not in your library yet",
                  systemImage: addToLibrary == nil ? "checkmark" : "globe")
              .font(.caption.weight(.semibold))
          } else if let category = joke.categories.first {
            Label { Text(category) } icon: { CategoryArtwork(name: category, size: 20) }
              .font(.caption.weight(.semibold))
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background(.white.opacity(0.35), in: Capsule())
          }
        }
        Spacer(minLength: 0)
        MustacheBadge(ink: theme.ink, paper: paper)
      }
      .padding(.bottom, 21)

      Text(joke.setup)
        .font(.system(size: headlineSize, weight: .bold, design: .serif))
        .accessibilityAddTraits(.isHeader)
        .fixedSize(horizontal: false, vertical: true)
        .contentTransition(.opacity)

      if joke.hasPunchline {
        TicketPerforation(ink: theme.ink)
          .frame(height: 1)
          .padding(.vertical, 21)
        if isVisible {
          Text(joke.punchline)
            .font(.system(.title3, design: .serif).weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 38, alignment: .leading)
            .transition(.opacity)
        } else {
          Button(action: reveal) {
            Label("Reveal punchline", systemImage: "sparkles")
              .font(.subheadline.weight(.bold))
              .padding(.horizontal, 15)
              .padding(.vertical, 10)
              .frame(minHeight: 44)
              .foregroundStyle(paper)
              .background(theme.ink, in: Capsule())
          }
          .buttonStyle(TicketButtonStyle())
          .accessibilityHint("Shows the answer to the joke")
        }
      }
      if let addToLibrary {
        Button("Add to Library", systemImage: "plus", action: addToLibrary)
          .buttonStyle(.plain)
          .font(.subheadline.weight(.bold))
          .padding(.top, 16)
          .frame(minHeight: 44, alignment: .leading)
      }
    }
    .foregroundStyle(theme.ink)
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(alignment: .topTrailing) {
      GeometryReader { geometry in
        TicketPrint(ink: theme.ink)
          .frame(width: min(geometry.size.width, 265), height: 192)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .background(paper)
      .accessibilityHidden(true)
    }
    .clipShape(.rect(cornerRadius: 28))
    .overlay {
      if isOnline {
        RoundedRectangle(cornerRadius: 28)
          .strokeBorder(theme.ink.opacity(0.56), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6]))
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
    .overlay(alignment: .topTrailing) {
      if !reduceMotion {
        Image(systemName: "sparkles")
          .font(.title2.weight(.semibold))
          .foregroundStyle(theme.ink)
          .symbolEffect(.bounce, value: revealCount)
          .opacity(revealCount == 0 || !isVisible ? 0 : 1)
          .padding(.top, 14)
          .padding(.trailing, 14)
          .accessibilityHidden(true)
          .allowsHitTesting(false)
      }
    }
  }
}

private struct MustacheBadge: View {
  var ink: Color
  var paper: Color

  var body: some View {
    ZStack {
      Circle().fill(ink)
      Circle().strokeBorder(paper.opacity(0.65), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        .padding(5)
      Image(systemName: "mustache.fill")
        .font(.system(size: 27, weight: .medium))
        .foregroundStyle(paper)
    }
    .frame(width: 65, height: 65)
    .rotationEffect(.degrees(-11))
    .accessibilityHidden(true)
  }
}

private struct TicketPrint: View {
  var ink: Color

  var body: some View {
    Canvas { context, size in
      let center = CGPoint(x: size.width * 0.77, y: 50)
      for index in 0..<24 {
        let angle = Double(index) * .pi / 12
        let ray = Path { path in
          path.move(to: center)
          path.addArc(center: center, radius: 140, startAngle: .radians(angle),
                      endAngle: .radians(angle + 0.072), clockwise: false)
          path.closeSubpath()
        }
        context.fill(ray, with: .color(ink.opacity(0.055)))
      }
      for x in stride(from: 7.0, to: size.width, by: 7) {
        for y in stride(from: 7.0, to: size.height, by: 7) {
          let distance = hypot(x - center.x, y - center.y)
          let opacity = 0.16 * max(0, 1 - distance / 120)
          context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                       with: .color(ink.opacity(opacity)))
        }
      }
    }
  }
}

private struct TicketPerforation: View {
  var ink: Color

  var body: some View {
    Canvas { context, size in
      let line = Path { path in
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: size.width, y: 0))
      }
      context.stroke(line, with: .color(ink.opacity(0.44)),
                     style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 5]))
    }
    .accessibilityHidden(true)
  }
}

private struct TicketButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.82 : 1)
  }
}
