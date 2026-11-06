import Foundation
import Observation
import WidgetKit

@Observable
final class HomeModel {
    var now: WeatherNow?
    var hours: HoursResponse?
    var forecast: ForecastResponse?
    var alerts: AlertsResponse?
    var nowcast: NowcastResponse?
    var radarSummary: RadarSummaryResponse?
    var report: ReportResponse?
    var nowcastError: String?
    var errorText: String?
    var loading = false
    var lastUpdate: Date?
    /// Set when the server was not reachable and stored answers are shown (oldest of them).
    var offlineSince: Date?

    /// "Now" for the display: the real clock, or the time of the example data in mock mode.
    var reference: Date {
        if APIClient.isMock, let t = Fmt.parse(now?.measuredTime) { return t }
        return Date()
    }

    @MainActor
    func load() async {
        loading = true
        defer { loading = false }
        // first start of the app: the stored answers right away, the server's after
        if now == nil, let stored: Fetched<WeatherNow> = APIClient.cached(.now) { now = stored.value }
        if hours == nil, let stored: Fetched<HoursResponse> = APIClient.cached(.hours) { hours = stored.value }
        if forecast == nil, let stored: Fetched<ForecastResponse> = APIClient.cached(.forecast16) { forecast = stored.value }
        if alerts == nil, let stored: Fetched<AlertsResponse> = APIClient.cached(.alerts) { alerts = stored.value }
        if nowcast == nil, let stored: Fetched<NowcastResponse> = APIClient.cached(.nowcast) { nowcast = stored.value }
        let api = APIClient()
        async let nowCall: Fetched<WeatherNow> = api.fetch(.now)
        async let hoursCall: Fetched<HoursResponse> = api.fetch(.hours)
        async let forecastCall: Fetched<ForecastResponse> = api.fetch(.forecast16)
        async let alertsCall: Fetched<AlertsResponse> = api.fetch(.alerts)
        async let nowcastCall: Fetched<NowcastResponse> = api.fetch(.nowcast)
        async let summaryCall: Fetched<RadarSummaryResponse> = api.fetch(.radarSummary)
        async let reportCall: Fetched<ReportResponse> = api.fetch(ReportKind.heute.endpoint)
        var problems: [String] = []
        var cached: [Date] = []
        var fresh = 0
        do {
            let r = try await nowCall
            now = r.value
            if r.fromCache { cached.append(r.date) } else { fresh += 1 }
        } catch { if !APIClient.isCancellation(error) { problems.append(error.localizedDescription) } }
        do {
            let r = try await hoursCall
            hours = r.value
            if r.fromCache { cached.append(r.date) } else { fresh += 1 }
        } catch { if !APIClient.isCancellation(error) { problems.append(error.localizedDescription) } }
        do {
            let r = try await forecastCall
            forecast = r.value
            if r.fromCache { cached.append(r.date) } else { fresh += 1 }
        } catch { if !APIClient.isCancellation(error) { problems.append(error.localizedDescription) } }
        do {
            alerts = try await alertsCall.value
        } catch {
            // no banner without an answer (the warnings screen explains a failed source)
        }
        do {
            nowcast = try await nowcastCall.value
            nowcastError = nil
        } catch {
            if !APIClient.isCancellation(error) { nowcastError = error.localizedDescription }
        }
        radarSummary = (try? await summaryCall)?.value ?? radarSummary
        report = (try? await reportCall)?.value ?? report
        errorText = problems.isEmpty ? nil : Array(Set(problems)).sorted().joined(separator: "\n")
        offlineSince = cached.min()
        if fresh > 0 {
            lastUpdate = Date()
            Haptics.refreshed()
            if !APIClient.isMock { WidgetCenter.shared.reloadAllTimelines() }
        }
    }

    /// The warning block when it has something for the banner.
    var bannerBlock: WarningBlock? {
        guard let block = alerts?.warnungen, block.known, let top = block.top else { return nil }
        // a stored answer may hold a warning that has ended meanwhile
        if let end = Fmt.parse(top.ende), end < reference { return nil }
        return block
    }

    // MARK: current

    var locationLabel: String { now?.location?.label ?? "Spexard" }

    var currentTemp: CurrentTemp { WeatherDerived.currentTemp(now) }

    var skyText: String? { WeatherDerived.skyText(now) }

    var isNight: Bool { isNight(at: reference) }

    func isNight(at date: Date) -> Bool { WeatherDerived.isNight(at: date, sun: hours?.sun) }

    var todaySun: HoursResponse.Sun? {
        let key = WeatherDerived.dayKey(reference)
        return hours?.sun?.first { $0.date == key }
    }

    var todayRange: (min: Double?, max: Double?) { WeatherDerived.todayRange(days, reference: reference) }

    // MARK: hours and days

    var hourItems: [HourItem] { WeatherDerived.hourItems(hours, reference: reference) }

    var sunEvents: [SunEvent] {
        let items = hourItems
        guard let first = items.first?.id, let last = items.last?.id else { return [] }
        return WeatherDerived.sunEvents(hours, from: first, to: last)
    }

    var days: [DayItem] { WeatherDerived.days(forecast, reference: reference) }

    /// Range of all daily values (for the temperature bars).
    var daysRange: ClosedRange<Double> {
        let values = days.flatMap { [$0.tmin, $0.tmax] }.compactMap { $0 }
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return 0...1 }
        return lo...hi
    }
}
