import Foundation

/// What the home screen and the widgets show, picked from the server's answers (no new values:
/// only choosing the best source and aligning hours and days).

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

    var shortSource: String {
        switch source {
        case .local: return "Sensor"
        case .station: return "DWD"
        case .model: return "Modell"
        case nil: return ""
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

enum WeatherDerived {
    /// The own sensor while it is current, else the DWD station, else the model (only chosen).
    static func currentTemp(_ now: WeatherNow?) -> CurrentTemp {
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
    static func skyText(_ now: WeatherNow?) -> String? {
        let w = now?.now?.weather
        if let m = w?.measured, m.split(separator: ",").contains(where: { $0.trimmingCharacters(in: .whitespaces) != "trocken" }) {
            return m
        }
        return w?.model ?? w?.measured
    }

    static func isNight(at date: Date, sun: [HoursResponse.Sun]?) -> Bool {
        let dayKey = Self.dayKey(date)
        if let sun = sun?.first(where: { $0.date == dayKey }),
           let rise = Self.clock(sun.sunrise, on: date), let set = Self.clock(sun.sunset, on: date) {
            return date < rise || date >= set
        }
        let h = Fmt.calendar.component(.hour, from: date)
        return h < 7 || h >= 17
    }

    /// The next `limit` hours from the current hour on.
    static func hourItems(_ hours: HoursResponse?, reference: Date, limit: Int = 24) -> [HourItem] {
        guard let h = hours?.hours else { return [] }
        let start = Fmt.calendar.dateInterval(of: .hour, for: reference)?.start ?? reference
        var items: [HourItem] = []
        for i in 0..<h.time.count {
            guard let date = Fmt.parse(h.time[i]), date >= start else { continue }
            let night = isNight(at: date, sun: hours?.sun)
            items.append(HourItem(
                id: date,
                label: items.isEmpty ? "Jetzt" : Fmt.hour(date) + " Uhr",
                symbol: WeatherSymbol.name(code: h.symbol[i], night: night),
                temp: h.tC[i],
                rainProb: h.rainProbPct[i],
                precip: h.precipMm[i]
            ))
            if items.count == limit { break }
        }
        return items
    }

    /// Days of `weather_forecast`: ECMWF-ENS median where available, else the median of the models.
    static func days(_ forecast: ForecastResponse?, reference: Date) -> [DayItem] {
        guard let list = forecast?.days else { return [] }
        let order = ["ecmwf", "icon", "gfs", "ukmo"]
        return list.compactMap { day in
            guard let date = Fmt.parse(day.date) else { return nil }
            let models = order.compactMap { day.models?[$0] ?? nil }
            let ens = day.ecmwfEns
            let tmax = ens?.tmaxC?[1] ?? median(models.compactMap(\.tmaxC))
            let tmin = ens?.tminC?[1] ?? median(models.compactMap(\.tminC))
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

    /// Min and max of today (first day of the forecast when it is today).
    static func todayRange(_ days: [DayItem], reference: Date) -> (min: Double?, max: Double?) {
        guard let today = days.first, Fmt.calendar.isDate(today.date, inSameDayAs: reference) else { return (nil, nil) }
        return (today.tmin, today.tmax)
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
