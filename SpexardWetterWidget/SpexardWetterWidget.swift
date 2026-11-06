import SwiftUI
import WidgetKit

struct WeatherEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    /// Gallery placeholder: grey shapes instead of a "no connection" note.
    var placeholder = false
}

struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), snapshot: nil, placeholder: true)
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
        WidgetContent(family: family, snapshot: entry.snapshot, placeholder: entry.placeholder)
            .containerBackground(for: .widget) {
                BackgroundGradient(night: entry.snapshot?.night ?? false)
            }
            .widgetURL(link)
    }

    /// Tap target: the warnings while the DWD warns, the radar when rain is coming, else home.
    private var link: URL? {
        guard let s = entry.snapshot else { return URL(string: "spexardwetter://wetter") }
        if s.warningTitle != nil { return URL(string: "spexardwetter://warnungen") }
        if let rain = s.rainHeadline, !rain.hasPrefix("Trocken") { return URL(string: "spexardwetter://radar") }
        return URL(string: "spexardwetter://wetter")
    }
}

struct SpexardWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpexardWetter", provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Spexard Wetter")
        .description("Aktuelle Temperatur, die nächsten Stunden und Regen in den nächsten zwei Stunden.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

struct RainWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry

    var body: some View {
        RainWidgetContent(family: family, snapshot: entry.snapshot, placeholder: entry.placeholder)
            .containerBackground(for: .widget) {
                BackgroundGradient(night: entry.snapshot?.night ?? false)
            }
            .widgetURL(URL(string: "spexardwetter://radar"))
    }
}

struct SpexardRainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpexardRegen", provider: WeatherProvider()) { entry in
            RainWidgetView(entry: entry)
        }
        .configurationDisplayName("Regen in 2 Stunden")
        .description("Radar-Nowcast des DWD am Standort: trocken oder wann der Regen kommt.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}

@main
struct SpexardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpexardWeatherWidget()
        SpexardRainWidget()
    }
}
