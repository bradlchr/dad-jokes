import SwiftUI

struct FoldDivision {
  var frame: CGRect
  var dividesHorizontally: Bool { frame.height > frame.width }

  static func insets(in geometry: GeometryProxy) -> FoldDivision? {
    #if os(iOS)
    if #available(iOS 27.1, *),
       let region = geometry.reservedRegions(kind: .division).first {
      let frame = region.frame
      let margins = region.margins
      let padded = CGRect(x: frame.minX - margins.leading, y: frame.minY - margins.top,
                          width: frame.width + margins.leading + margins.trailing,
                          height: frame.height + margins.top + margins.bottom)
      let bounds = CGRect(origin: .zero, size: geometry.size)
      let visible = bounds.intersection(padded)
      if !visible.isNull, !visible.isEmpty {
        let vertical = frame.height > frame.width
        if vertical ? visible.minX > 0 && visible.maxX < bounds.maxX
          : visible.minY > 0 && visible.maxY < bounds.maxY {
          return FoldDivision(frame: visible)
        }
      }
    }
    #endif
    return nil
  }
}

struct DuoLayout<Standard: View, Primary: View, Secondary: View>: View {
  @ViewBuilder var standard: (CGSize) -> Standard
  @ViewBuilder var primary: (CGSize) -> Primary
  @ViewBuilder var secondary: (CGSize) -> Secondary

  var body: some View {
    GeometryReader { geometry in
      #if os(iOS)
      if #available(iOS 27.1, *), let fold = FoldDivision.insets(in: geometry) {
        ArrangementView {
          GeometryReader { primary($0.size) }
        } secondary: {
          GeometryReader { secondary($0.size) }
        }
        .arrangementViewStyle(.split.axes(fold.dividesHorizontally ? .horizontal : .vertical))
      } else {
        standard(geometry.size)
      }
      #else
      standard(geometry.size)
      #endif
    }
  }
}
