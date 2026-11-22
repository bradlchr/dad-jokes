import SwiftUI

struct StageSet: View {
  var performer: StagePerformer
  var reaction: Int
  var speaking: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      ZStack(alignment: .bottom) {
        StageBackdrop()
          .accessibilityHidden(true)
        Image(performer.image)
          .resizable()
          .scaledToFit()
          .frame(width: width * 0.68, height: height * 0.94)
          .scaleEffect(speaking && !reduceMotion ? 1.022 : 1, anchor: .bottom)
          .animation(reduceMotion ? nil : .smooth, value: speaking)
          .padding(.bottom, height * 0.09)
          .accessibilityLabel(performer.accessibilityDescription)
        StageAudience(reaction: reaction)
          .frame(height: height * 0.24)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

private struct StageBackdrop: View {
  var body: some View {
    Canvas { context, size in
      let w = size.width
      let h = size.height
      let beam = Path { p in
        p.move(to: CGPoint(x: w * 0.45, y: 0))
        p.addLine(to: CGPoint(x: w * 0.55, y: 0))
        p.addLine(to: CGPoint(x: w * 0.81, y: h * 0.83))
        p.addQuadCurve(to: CGPoint(x: w * 0.19, y: h * 0.83),
                       control: CGPoint(x: w * 0.5, y: h * 1.05))
        p.closeSubpath()
      }
      context.fill(beam, with: .linearGradient(
        Gradient(colors: [Color(red: 1, green: 0.75, blue: 0.39).opacity(0.32),
                          Color(red: 0.80, green: 0.36, blue: 0.55).opacity(0.13)]),
        startPoint: CGPoint(x: w * 0.47, y: 0), endPoint: CGPoint(x: w * 0.54, y: h)))
      let floor = Path(ellipseIn: CGRect(x: w * 0.15, y: h * 0.77, width: w * 0.70, height: h * 0.16))
      context.fill(floor, with: .radialGradient(
        Gradient(colors: [Color(red: 0.86, green: 0.48, blue: 0.47).opacity(0.36), .clear]),
        center: CGPoint(x: w * 0.50, y: h * 0.85), startRadius: 3, endRadius: w * 0.35))

      for side in [-1.0, 1.0] {
        let edge = side < 0 ? 0 : w
        let curtain = Path { p in
          p.move(to: CGPoint(x: edge, y: 0))
          p.addLine(to: CGPoint(x: edge - side * w * 0.23, y: 0))
          p.addQuadCurve(to: CGPoint(x: edge - side * w * 0.06, y: h * 0.62),
                         control: CGPoint(x: edge - side * w * 0.16, y: h * 0.52))
          p.addLine(to: CGPoint(x: edge - side * w * 0.13, y: h * 0.90))
          p.addLine(to: CGPoint(x: edge, y: h * 0.90))
          p.closeSubpath()
        }
        context.fill(curtain, with: .linearGradient(
          Gradient(colors: [Color(red: 0.24, green: 0.08, blue: 0.25), .clear]),
          startPoint: CGPoint(x: edge, y: 0), endPoint: CGPoint(x: edge - side * w * 0.25, y: h * 0.10)))
      }
    }
  }
}

private struct StageAudience: View {
  var reaction: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Canvas { context, size in
      guard size.width > 0 else { return }
      for index in 0..<13 {
        let spacing = size.width / 12
        let x = CGFloat(index) * spacing
        let edge = abs(x - size.width / 2) / (size.width / 2)
        let scale = min(spacing * 0.77, 36.0) * (index.isMultiple(of: 3) ? 1.18 : 0.87)
        let y = size.height * (0.63 - 0.38 * edge) + CGFloat(index % 3) * 5
        let shade = Color(red: 0.12 + Double(index % 3) * 0.021, green: 0.06, blue: 0.20)
        context.fill(Path(ellipseIn: CGRect(x: x - scale * 0.40, y: y, width: scale * 0.8, height: scale)),
                     with: .color(shade))
        context.fill(Path(ellipseIn: CGRect(x: x - scale * 0.73, y: y + scale * 0.79,
                                            width: scale * 1.46, height: size.height)), with: .color(shade))
      }
    }
    .clipped()
    .phaseAnimator(reduceMotion ? [false] : [false, true, false], trigger: reaction) { content, raised in
      content.offset(y: raised ? -6 : 0)
    } animation: { _ in .snappy(duration: 0.32) }
  }
}
