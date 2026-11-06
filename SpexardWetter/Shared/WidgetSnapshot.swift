import Foundation

extension Endpoint {
    static let forecast7 = Endpoint(path: "/api/v1/tools/weather_forecast?days=7", mock: "mock_forecast")
}

/// Everything a widget shows, taken from the server's answers (shared by the widget extension and
/// the widget preview in the app).
struct WidgetSnapshot {
    let place: String
    let temp: Double?
    let source: CurrentTemp.Source?
    let time: Date?
    let symbol: String
    let sky: String?
    let min: Double?
    let max: Double?
    let hours: [HourItem]
    /// The next days (large widget).
    let days: [DayItem]
    /// Current station values ("Verlauf & Live").
    let live: LiveValues
    /// 3-hour columns from now on ("Verlauf & Live").
    let strip: [StripColumn]
    let rainHeadline: String?
    /// Radar nowcast at the location in 5-minute steps (measured, then forecast).
    let rainSteps: [NowcastResponse.Step]
    let rainText: String?
    let warningTitle: String?
    let warningLevel: Int?
    let warningIsPre: Bool
    let night: Bool
    /// When the answers were fetched; `offline` = stored answers.
    let stand: Date
    let offline: Bool

    var shortPlace: String {
        place.split(separator: "-").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? place
    }

    /// Loads the answers the widgets need. Nil when not even the current values are available.
    static func load() async -> WidgetSnapshot? {
        let api = APIClient()
        async let nowCall: Fetched<WeatherNow> = api.fetch(.now, timeout: 15)
        async let hoursCall: Fetched<HoursResponse> = api.fetch(.hours, timeout: 15)
        async let forecastCall: Fetched<ForecastResponse> = api.fetch(.forecast7, timeout: 15)
        async let nowcastCall: Fetched<NowcastResponse> = api.fetch(.nowcast, timeout: 15)
        async let alertsCall: Fetched<AlertsResponse> = api.fetch(.alerts, timeout: 15)
        guard let now = try? await nowCall else { return nil }
        let hours = try? await hoursCall
        let forecast = try? await forecastCall
        let nowcast = try? await nowcastCall
        let alerts = try? await alertsCall

        let reference: Date = APIClient.isMock ? (Fmt.parse(now.value.measuredTime) ?? Date()) : Date()
        let current = WeatherDerived.currentTemp(now.value)
        let sky = WeatherDerived.skyText(now.value)
        let night = WeatherDerived.isNight(at: reference, sun: hours?.value.sun)
        let days = WeatherDerived.days(forecast?.value, reference: reference)
        let range = WeatherDerived.todayRange(days, reference: reference)
        let block = alerts?.value.warnungen
        let top = (block?.known ?? false) ? block?.top : nil
        let offline = [now.fromCache, hours?.fromCache ?? false, forecast?.fromCache ?? false].contains(true)
        return WidgetSnapshot(
            place: now.value.location?.label ?? "Spexard",
            temp: current.value,
            source: current.source,
            time: current.time,
            symbol: WeatherSymbol.name(text: sky, night: night),
            sky: sky.map { $0.prefix(1).uppercased() + $0.dropFirst() },
            min: range.min,
            max: range.max,
            hours: WeatherDerived.hourItems(hours?.value, reference: reference, limit: 6),
            days: Array(days.prefix(6)),
            live: LiveValues.from(now.value),
            strip: WeatherDerived.strip(hours?.value, reference: reference, step: 3, count: 14),
            rainHeadline: nowcast?.value.headline,
            rainSteps: nowcast?.value.steps ?? [],
            rainText: nowcast?.value.summary?.text,
            warningTitle: top?.title,
            warningLevel: top?.stufe,
            warningIsPre: block?.topIsPre ?? false,
            night: night,
            stand: now.date,
            offline: offline
        )
    }
}
