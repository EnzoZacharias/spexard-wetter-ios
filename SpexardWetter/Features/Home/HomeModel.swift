import Foundation
import Observation

struct CurrentTemp {
    enum Source { case local, station, model }
    let value: Double?
    let source: Source?
    let time: Date?
    /// Sensor name (local) or station name (station).
    let name: String?

    var sourceText: String {
        switch source {
        case .local: return "\(name ?? "Eigener Sensor") · \(Fmt.time(time))"
        case .station: return "DWD-Station \(name ?? "") · \(Fmt.time(time))"
        case .model: return "Modell ICON-D2 · \(Fmt.time(time))"
        case nil: return "Keine aktuellen Werte"
        }
    }
}

struct HourItem: Identifiable {
    let id: Date
    let label: String
    let symbol: String
    let temp: Double?
    let rainProb: Double?
    let precip: Double?
}

struct DayItem: Identifiable {
    let id: String
    let date: Date
    let label: String
    let dateLabel: String
    let symbol: String
    let tmin: Double?
    let tmax: Double?
    let rainProb: Double?
    let confidence: String?
}

@Observable
final class HomeModel {
    var now: WeatherNow?
    var hours: HoursResponse?
    var forecast: ForecastResponse?
    var alerts: AlertsResponse?
    var nowcast: NowcastResponse?
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
        let api = APIClient()
        async let nowCall: Fetched<WeatherNow> = api.fetch(.now)
        async let hoursCall: Fetched<HoursResponse> = api.fetch(.hours)
        async let forecastCall: Fetched<ForecastResponse> = api.fetch(.forecast16)
        async let alertsCall: Fetched<AlertsResponse> = api.fetch(.alerts)
        async let nowcastCall: Fetched<NowcastResponse> = api.fetch(.nowcast)
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
        errorText = problems.isEmpty ? nil : Array(Set(problems)).sorted().joined(separator: "\n")
        offlineSince = cached.min()
        if fresh > 0 {
            lastUpdate = Date()
            Haptics.refreshed()
        }
    }

    /// The warning block when it has something for the banner.
    var bannerBlock: WarningBlock? {
        guard let block = alerts?.warnungen, block.known, block.top != nil else { return nil }
        return block
    }

    // MARK: current

    var locationLabel: String { now?.location?.label ?? "Spexard" }

    /// The own sensor while it is current, else the DWD station, else the model (only chosen).
    var currentTemp: CurrentTemp {
        if let s = now?.localSensor, s.current == true, let v = s.temperatureC {
            return CurrentTemp(value: v, source: .local, time: Fmt.parse(s.time), name: s.name)
        }
        let t = now?.now?.temperatureC
        if let v = t?.measured {
            return CurrentTemp(value: v, source: .station, time: Fmt.parse(now?.measuredTime), name: t?.station)
        }
        if let v = t?.model {
            return CurrentTemp(value: v, source: .model, time: Fmt.parse(now?.modelTime), name: nil)
        }
        return CurrentTemp(value: nil, source: nil, time: nil, name: nil)
    }

    /// Station text when it says something about the sky, else the model text.
    var skyText: String? {
        let w = now?.now?.weather
        if let m = w?.measured, m.split(separator: ",").contains(where: { $0.trimmingCharacters(in: .whitespaces) != "trocken" }) {
            return m
        }
        return w?.model ?? w?.measured
    }

    var isNight: Bool { isNight(at: reference) }

    func isNight(at date: Date) -> Bool {
        let cal = Fmt.calendar
        let dayKey = Self.dayKey(date)
        if let sun = hours?.sun?.first(where: { $0.date == dayKey }),
           let rise = Self.clock(sun.sunrise, on: date), let set = Self.clock(sun.sunset, on: date) {
            return date < rise || date >= set
        }
        let h = cal.component(.hour, from: date)
        return h < 7 || h >= 17
    }

    var todayRange: (min: Double?, max: Double?) {
        guard let today = days.first, Fmt.calendar.isDate(today.date, inSameDayAs: reference) else { return (nil, nil) }
        return (today.tmin, today.tmax)
    }

    // MARK: hours

    /// The next 24 hours from the current hour on.
    var hourItems: [HourItem] {
        guard let h = hours?.hours else { return [] }
        let start = Fmt.calendar.dateInterval(of: .hour, for: reference)?.start ?? reference
        var items: [HourItem] = []
        for i in 0..<h.time.count {
            guard let date = Fmt.parse(h.time[i]), date >= start else { continue }
            let night = isNight(at: date)
            items.append(HourItem(
                id: date,
                label: items.isEmpty ? "Jetzt" : Fmt.hour(date) + " Uhr",
                symbol: WeatherSymbol.name(code: h.symbol[i], night: night),
                temp: h.tC[i],
                rainProb: h.rainProbPct[i],
                precip: h.precipMm[i]
            ))
            if items.count == 24 { break }
        }
        return items
    }

    // MARK: days

    var days: [DayItem] {
        guard let list = forecast?.days else { return [] }
        let order = ["ecmwf", "icon", "gfs", "ukmo"]
        return list.compactMap { day in
            guard let date = Fmt.parse(day.date) else { return nil }
            let models = order.compactMap { day.models?[$0] ?? nil }
            let ens = day.ecmwfEns
            let tmax = ens?.tmaxC?[1] ?? Self.median(models.compactMap(\.tmaxC))
            let tmin = ens?.tminC?[1] ?? Self.median(models.compactMap(\.tminC))
            if tmax == nil && tmin == nil { return nil }  // no model reaches this day
            let text = models.compactMap(\.weather).first
            return DayItem(
                id: day.date,
                date: date,
                label: Fmt.weekday(date, reference: reference),
                dateLabel: Fmt.dayMonth(date),
                symbol: WeatherSymbol.name(text: text, night: false),
                tmin: tmin,
                tmax: tmax,
                rainProb: ens?.rainAnyProbPct ?? ens?.rainProbPct,
                confidence: day.confidence?.level
            )
        }
    }

    /// Range of all daily values (for the temperature bars).
    var daysRange: ClosedRange<Double> {
        let values = days.flatMap { [$0.tmin, $0.tmax] }.compactMap { $0 }
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return 0...1 }
        return lo...hi
    }

    // MARK: helpers

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    static func dayKey(_ date: Date) -> String {
        let c = Fmt.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "07:25" on the day of `date`.
    static func clock(_ text: String?, on date: Date) -> Date? {
        guard let text else { return nil }
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Fmt.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date)
    }
}
