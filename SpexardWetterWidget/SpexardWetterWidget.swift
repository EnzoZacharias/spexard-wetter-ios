import SwiftUI
import WidgetKit

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        Task {
            let snapshot = await WidgetSnapshot.load()
            completion(WeatherEntry(date: Date(), snapshot: snapshot))
        }
    }

    /// One entry per load; the next load after 20 minutes (15 after a failure).
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let snapshot = await WidgetSnapshot.load()
            let minutes: Double = snapshot == nil ? 15 : 20
            let entry = WeatherEntry(date: Date(), snapshot: snapshot)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(minutes * 60))))
        }
    }
}

struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry

    var body: some View {
        WidgetContent(family: family, snapshot: entry.snapshot)
            .containerBackground(for: .widget) {
                BackgroundGradient(night: entry.snapshot?.night ?? false)
            }
    }
}

struct SpexardWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpexardWetter", provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Spexard Wetter")
        .description("Aktuelle Temperatur, die nächsten Stunden und Regen in den nächsten zwei Stunden.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

@main
struct SpexardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpexardWeatherWidget()
    }
}
