import AppIntents
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

// MARK: - Messwert (configurable: which quantity)

/// Settings of the "Messwert" widget (long press → Widget bearbeiten).
struct MeasurementWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Messwert"
    static var description = IntentDescription("Welche Messgröße das Widget zeigt.")

    @Parameter(title: "Messgröße", default: .temperatur)
    var groesse: MeasurementKind
}

struct MeasurementEntry: TimelineEntry {
    let date: Date
    let kind: MeasurementKind
    let data: MeasurementWidgetData?
    var placeholder = false
}

struct MeasurementProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MeasurementEntry {
        MeasurementEntry(date: Date(), kind: .temperatur, data: nil, placeholder: true)
    }

    func snapshot(for configuration: MeasurementWidgetIntent, in context: Context) async -> MeasurementEntry {
        MeasurementEntry(date: Date(), kind: configuration.groesse, data: await MeasurementWidgetData.load(configuration.groesse))
    }

    /// The stations report every 10 minutes; the next load after 20 minutes (15 after a failure).
    func timeline(for configuration: MeasurementWidgetIntent, in context: Context) async -> Timeline<MeasurementEntry> {
        let data = await MeasurementWidgetData.load(configuration.groesse)
        let minutes: Double = data == nil ? 15 : 20
        let entry = MeasurementEntry(date: Date(), kind: configuration.groesse, data: data)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(minutes * 60)))
    }
}

struct MeasurementWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MeasurementEntry

    var body: some View {
        MeasurementWidgetContent(family: family, data: entry.data, kind: entry.kind, placeholder: entry.placeholder)
            .containerBackground(for: .widget) {
                BackgroundGradient(night: true)
            }
            .widgetURL(URL(string: "spexardwetter://messwerte"))
    }
}

/// One current value of choice with its station, time and the model value next to it.
struct SpexardMeasurementWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SpexardMesswert", intent: MeasurementWidgetIntent.self, provider: MeasurementProvider()) { entry in
            MeasurementWidgetView(entry: entry)
        }
        .configurationDisplayName("Messwert")
        .description("Ein Messwert nach Wahl mit Station, Uhrzeit und dem Modellwert daneben. Welcher: lange drücken, „Widget bearbeiten“.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Ort (configurable: a place of choice)

/// A place found by the server's search. Everything the widget needs sits in the id, so the
/// widget needs no list of places on the device (no App Group): "52.09|8.74|Bad Salzuflen|Kreis Lippe".
struct PlaceEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Ort"
    static var defaultQuery = PlaceEntityQuery()

    let id: String

    init(_ place: Place) {
        id = [String(format: "%.2f", place.lat), String(format: "%.2f", place.lon), place.name, place.region ?? ""]
            .map { $0.replacingOccurrences(of: "|", with: "/") }
            .joined(separator: "|")
    }

    init?(id: String) {
        let parts = id.components(separatedBy: "|")
        guard parts.count >= 3, Double(parts[0]) != nil, Double(parts[1]) != nil else { return nil }
        self.id = id
    }

    var place: Place? {
        let parts = id.components(separatedBy: "|")
        guard parts.count >= 3, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
        let region = parts.count > 3 && !parts[3].isEmpty ? parts[3] : nil
        return Place(id: 0, name: parts[2], region: region, lat: lat, lon: lon, hoeheM: nil)
    }

    var displayRepresentation: DisplayRepresentation {
        let p = place
        return DisplayRepresentation(title: "\(p?.name ?? "Ort")", subtitle: "\(p?.region ?? "")")
    }
}

/// The search of the server while typing in the widget's settings (each text is one request).
struct PlaceEntityQuery: EntityStringQuery {
    func entities(for identifiers: [PlaceEntity.ID]) async throws -> [PlaceEntity] {
        identifiers.compactMap { PlaceEntity(id: $0) }
    }

    func entities(matching string: String) async throws -> [PlaceEntity] {
        // the editor asks while typing: from three letters on (the server allows 60 searches per day and visitor)
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 3 else { return [] }
        let answer: Fetched<PlaceSearchResponse> = try await APIClient().fetch(.placeSearch(text), timeout: 15)
        return (answer.value.treffer ?? []).map { PlaceEntity($0) }
    }

    func suggestedEntities() async throws -> [PlaceEntity] { [] }
}

struct PlaceWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Ort"
    static var description = IntentDescription("Für welchen Ort in Deutschland das Widget die Vorhersage zeigt.")

    @Parameter(title: "Ort")
    var ort: PlaceEntity?
}

struct PlaceEntry: TimelineEntry {
    let date: Date
    let placeName: String?
    let data: PlaceWidgetData?
    var placeholder = false
}

struct PlaceProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlaceEntry {
        PlaceEntry(date: Date(), placeName: "Ort", data: nil, placeholder: true)
    }

    func snapshot(for configuration: PlaceWidgetIntent, in context: Context) async -> PlaceEntry {
        await entry(configuration)
    }

    /// Model values change with the model runs: the next load after an hour (20 minutes after a failure).
    func timeline(for configuration: PlaceWidgetIntent, in context: Context) async -> Timeline<PlaceEntry> {
        let e = await entry(configuration)
        let minutes: Double = e.data == nil ? 20 : 60
        return Timeline(entries: [e], policy: .after(Date().addingTimeInterval(minutes * 60)))
    }

    private func entry(_ configuration: PlaceWidgetIntent) async -> PlaceEntry {
        guard let place = configuration.ort?.place else { return PlaceEntry(date: Date(), placeName: nil, data: nil) }
        return PlaceEntry(date: Date(), placeName: place.name, data: await PlaceWidgetData.load(place))
    }
}

struct PlaceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlaceEntry

    var body: some View {
        PlaceWidgetContent(family: family, data: entry.data, placeName: entry.placeName, placeholder: entry.placeholder)
            .containerBackground(for: .widget) {
                BackgroundGradient(night: true)
            }
    }
}

/// The lean forecast of a place of choice (not Spexard: that is what the other widgets show).
struct SpexardPlaceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SpexardOrt", intent: PlaceWidgetIntent.self, provider: PlaceProvider()) { entry in
            PlaceWidgetView(entry: entry)
        }
        .configurationDisplayName("Ort nach Wahl")
        .description("Vorhersage für einen anderen Ort in Deutschland (Modellwerte, Warnungen der Gemeinde). Den Ort wählt man mit „Widget bearbeiten“.")
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
        SpexardMeasurementWidget()
        SpexardPlaceWidget()
    }
}
