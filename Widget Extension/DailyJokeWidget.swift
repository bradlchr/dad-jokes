import SwiftUI
import WidgetKit

struct DailyJokeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DailyJoke", provider: DailyJokeProvider()) { entry in
      DailyJokeWidgetView(joke: entry.joke)
        .widgetURL(JokeCatalog.dailyURL)
    }
    .configurationDisplayName("Joke of the Day")
    .description("A fresh dad joke every day. Tap to reveal the punchline.")
    #if os(watchOS)
    .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    #elseif os(iOS)
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    #else
    .supportedFamilies([.systemSmall, .systemMedium])
    #endif
  }
}

private struct DailyJokeProvider: TimelineProvider {
  func placeholder(in context: Context) -> DailyJokeEntry {
    DailyJokeEntry(date: Date(), joke: JokeCatalog.fallback)
  }

  func getSnapshot(in context: Context, completion: @escaping (DailyJokeEntry) -> Void) {
    let date = Date()
    completion(DailyJokeEntry(date: date, joke: JokeCatalog.daily(on: date)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<DailyJokeEntry>) -> Void) {
    let now = Date()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)
    let dates = [now] + (1...6).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    let entries = dates.map { DailyJokeEntry(date: $0, joke: JokeCatalog.daily(on: $0)) }
    let refresh = calendar.date(byAdding: .day, value: 7, to: today) ?? now.addingTimeInterval(86400)
    completion(Timeline(entries: entries, policy: .after(refresh)))
  }
}

private struct DailyJokeEntry: TimelineEntry {
  var date: Date
  var joke: Joke
}

private struct DailyJokeWidgetView: View {
  var joke: Joke
  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetRenderingMode) private var renderingMode

  private let paper = Color(red: 1, green: 0.85, blue: 0.47)
  private let ink = Color(red: 0.17, green: 0.10, blue: 0.31)

  var body: some View {
    switch family {
    #if os(watchOS)
    case .accessoryCircular:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "mustache.fill")
          .font(.title3.weight(.semibold))
          .widgetAccentable()
      }
      .accessibilityLabel("Joke of the Day")
      .containerBackground(for: .widget) { Color.clear }
    #endif
    #if os(iOS) || os(watchOS)
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label("Dad Jokes", systemImage: "mustache.fill")
          .font(.caption2.weight(.bold))
          .widgetAccentable()
        Text(joke.setup).font(.caption).lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .containerBackground(for: .widget) { Color.clear }
    #endif
    default:
      #if os(watchOS)
      EmptyView()
      #else
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Joke of the Day").font(.caption2.weight(.heavy)).textCase(.uppercase)
          Spacer(minLength: 4)
          Image(systemName: "mustache.fill")
            .font(.callout.weight(.semibold))
            .widgetAccentable()
            .accessibilityHidden(true)
        }
        Spacer(minLength: 3)
        Text(joke.setup)
          .font(.system(family == .systemSmall ? .body : .title3, design: .serif).weight(.bold))
          .lineLimit(4)
          .minimumScaleFactor(0.8)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 3)
        if joke.hasPunchline {
          Text("Tap to reveal")
            .font(.caption2.weight(.semibold))
            .widgetAccentable()
        }
      }
      .foregroundStyle(renderingMode == .fullColor ? AnyShapeStyle(ink) : AnyShapeStyle(.primary))
      .containerBackground(paper.gradient, for: .widget)
      #endif
    }
  }
}
