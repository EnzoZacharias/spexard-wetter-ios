import Foundation

/// One column of the forecast strip ("Verlauf & Live" widget): a step of usually 3 hours.
struct StripColumn: Identifiable {
    let id: Date
    /// "18" (hour of the column start).
    let hour: String
    /// Weekday ("Sa") on the first column of a new day, else nil.
    let day: String?
    let symbol: String
    let temp: Double?
    /// Sum of the hourly precipitation of the step (nil when the server has no values).
    let precip: Double?
    /// Mean wind at the column hour.
    let wind: Double?
    /// Highest gust of the step.
    let gust: Double?
    /// Direction the wind comes FROM (degrees).
    let windDir: Double?
    let night: Bool
}

/// Current values of `weather_now` for the live part: the measured value where a DWD station has
/// one, else the model; the temperature as everywhere (own sensor > station > model).
struct LiveValues {
    struct Value {
        let value: Double
        let measured: Bool
        let station: String?
    }

    let temp: CurrentTemp
    let dewPoint: Value?
    let humidity: Value?
    let wind: Value?
    /// Strongest measured gust of the last hour, else the current gust (measured or model).
    let gust: Value?
    let windDir: Double?
    let pressure: Value?
    /// Measured precipitation of the last hour.
    let rain1h: Value?

    static func from(_ now: WeatherNow?) -> LiveValues {
        let n = now?.now
        func value(_ pair: WeatherNow.Pair?) -> Value? {
            guard let best = pair?.best else { return nil }
            return Value(value: best.value, measured: best.measured, station: best.measured ? pair?.station : nil)
        }
        var gust = value(n?.windGustsKmh)
        if let max60 = n?.windGustsKmh?.measuredMax60min {
            gust = Value(value: max60, measured: true, station: n?.windGustsKmh?.station)
        }
        var rain: Value?
        if let mm = n?.precipitationMm?.measured60min {
            rain = Value(value: mm, measured: true, station: n?.precipitationMm?.station)
        }
        return LiveValues(
            temp: WeatherDerived.currentTemp(now),
            dewPoint: value(n?.dewPointC),
            humidity: value(n?.humidityPct),
            wind: value(n?.windSpeedKmh),
            gust: gust,
            windDir: n?.windDirectionDeg?.best?.value,
            pressure: value(n?.pressureMslHpa),
            rain1h: rain
        )
    }

    /// Stations of the measured values, each once ("Bielefeld-Deppendorf, Guetersloh/Ems").
    var stations: [String] {
        var out: [String] = []
        for v in [dewPoint, humidity, wind, gust, pressure, rain1h] {
            if let s = v?.station, !out.contains(s) { out.append(s) }
        }
        if temp.source == .station, let s = temp.name, !out.contains(s) { out.insert(s, at: 0) }
        return out
    }
}

extension WeatherDerived {
    /// Columns every `step` hours from the current hour on, `count` at most (fewer where the
    /// hourly forecast ends).
    static func strip(_ hours: HoursResponse?, reference: Date, step: Int = 3, count: Int = 14) -> [StripColumn] {
        guard let h = hours?.hours else { return [] }
        let start = Fmt.calendar.dateInterval(of: .hour, for: reference)?.start ?? reference
        var index: [Date: Int] = [:]
        for i in 0..<h.time.count {
            if let d = Fmt.parse(h.time[i]) { index[d] = i }
        }
        var out: [StripColumn] = []
        var previousDay: Int?
        for k in 0..<count {
            let t = start.addingTimeInterval(Double(k * step) * 3600)
            guard let i = index[t] else { break }
            var rain: Double?
            var gustMax: Double?
            for s in 0..<step {
                guard let j = index[t.addingTimeInterval(Double(s) * 3600)] else { continue }
                if let p = h.precipMm[j] { rain = (rain ?? 0) + p }
                if let g = h.gustMaxKmh[j] { gustMax = Swift.max(gustMax ?? g, g) }
            }
            let day = Fmt.calendar.component(.day, from: t)
            let dayLabel = previousDay != nil && previousDay != day ? Fmt.weekdayShort(t) : nil
            previousDay = day
            let middle = t.addingTimeInterval(Double(step) * 1800)
            let night = isNight(at: middle, sun: hours?.sun)
            out.append(StripColumn(
                id: t,
                hour: Fmt.hour(t),
                day: dayLabel,
                symbol: WeatherSymbol.name(code: h.symbol[i], night: night),
                temp: h.tC[i],
                precip: rain,
                wind: h.windKmh[i],
                gust: gustMax ?? h.gustMaxKmh[i],
                windDir: h.windDirDeg[i],
                night: night
            ))
        }
        return out
    }
}

/// Beaufort number from km/h (WMO limits in m/s, like the website's wind helper).
enum Beaufort {
    private static let limitsMs: [Double] = [0.2, 1.5, 3.3, 5.4, 7.9, 10.7, 13.8, 17.1, 20.7, 24.4, 28.4, 32.6]

    static func number(_ kmh: Double) -> Int {
        let ms = (Swift.max(0, kmh) / 3.6 * 10).rounded() / 10
        return limitsMs.firstIndex { ms <= $0 } ?? 12
    }
}
