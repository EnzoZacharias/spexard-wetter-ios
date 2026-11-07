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

struct LiveStripWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry

    var body: some View {
        LiveStripWidget(family: family, snapshot: entry.snapshot, placeholder: entry.placeholder)
            .containerBackground(for: .widget) {
                BackgroundGradient(night: entry.snapshot?.night ?? false)
            }
            .widgetURL(URL(string: "spexardwetter://meteogramm"))
    }
}

/// Live values of the stations plus the next 27 to 39 hours in 3-hour columns.
struct SpexardLiveStripWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpexardVerlauf", provider: WeatherProvider()) { entry in
            LiveStripWidgetView(entry: entry)
        }
        .configurationDisplayName("Verlauf & Live")
        .description("Messwerte jetzt (Temperatur, Taupunkt, Feuchte, Wind, Druck) und die nächsten Stunden mit Temperaturkurve, Regen, Wind und Böen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Historie (own provider: only this widget asks for the history)

struct HistoryEntry: TimelineEntry {
    let date: Date
    let data: HistoryWidgetData?
    var placeholder = false
}

struct HistoryProvider: TimelineProvider {
    func placeholder(in context: Context) -> HistoryEntry {
        HistoryEntry(date: Date(), data: nil, placeholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (HistoryEntry) -> Void) {
        Task {
            completion(HistoryEntry(date: Date(), data: await HistoryWidgetData.load()))
        }
    }

    /// The garden log grows every 10 minutes; the next load after 30 minutes (15 after a failure).
    func getTimeline(in context: Context, completion: @escaping (Timeline<HistoryEntry>) -> Void) {
        Task {
            let data = await HistoryWidgetData.load()
            let minutes: Double = data == nil ? 15 : 30
            let entry = HistoryEntry(date: Date(), data: data)
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(minutes * 60))))
        }
    }
}

struct HistoryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HistoryEntry

    var body: some View {
        HistoryWidgetContent(family: family, data: entry.data, placeholder: entry.placeholder)
            .containerBackground(for: .widget) {
                BackgroundGradient(night: false)
            }
            .widgetURL(URL(string: "spexardwetter://historie"))
    }
}

/// Today so far in the garden, the month and the records of the own sensor.
struct SpexardHistoryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpexardHistorie", provider: HistoryProvider()) { entry in
            HistoryWidgetView(entry: entry)
        }
        .configurationDisplayName("Historie Garten")
        .description("Tiefst- und Höchstwert des Gartensensors heute, im Monat und seit Beginn der Messung.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct SpexardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpexardWeatherWidget()
        SpexardLiveStripWidget()
        SpexardRainWidget()
        SpexardHistoryWidget()
    }
}
