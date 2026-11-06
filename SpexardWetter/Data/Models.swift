import Foundation

/// A series from the server (`[1.2, null, 3.4]`). The server collapses a constant series into a
/// sentence ("0.0 mm in allen Stunden", "0 % in der gesamten Vorhersage"): such a value decodes as
/// `constant`, which every index then returns. Anything else unreadable decodes as an empty series
/// instead of failing the whole answer.
struct Series<T: Decodable>: Decodable {
    let values: [T?]
    /// Value of a collapsed series, else nil.
    let constant: T?
    /// The server's sentence of a collapsed series.
    let text: String?

    init(values: [T?] = []) {
        self.values = values
        constant = nil
        text = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([T?].self) {
            values = list
            constant = nil
            text = nil
        } else if let sentence = try? container.decode(String.self) {
            values = []
            text = sentence
            constant = Self.collapsedValue(sentence)
        } else {
            values = []
            constant = nil
            text = nil
        }
    }

    subscript(index: Int) -> T? {
        if values.indices.contains(index) { return values[index] }
        return values.isEmpty ? constant : nil
    }

    var count: Int { values.count }
    var isCollapsed: Bool { values.isEmpty && text != nil }

    /// `length` values aligned with a time axis (a collapsed series repeats its value).
    func expanded(_ length: Int) -> [T?] {
        (0..<max(length, 0)).map { self[$0] }
    }

    /// "0.0 mm in allen Stunden" -> 0 (numbers), "ja in allen ..." -> true, "keine Daten" -> nil.
    static func collapsedValue(_ text: String) -> T? {
        guard let head = Self.collapsedHead(text) else { return nil }
        if T.self == String.self { return head as? T }
        if T.self == Bool.self {
            if head == "ja" { return true as? T }
            if head == "nein" { return false as? T }
            return nil
        }
        let first = head.split(separator: " ").first.map(String.init) ?? head
        guard let number = Double(first.replacingOccurrences(of: ",", with: ".")) else { return nil }
        if T.self == Double.self { return number as? T }
        if T.self == Int.self { return Int(number.rounded()) as? T }
        return nil
    }

    private static func collapsedHead(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for marker in [" in allen ", " in der gesamten "] {
            if let range = trimmed.range(of: marker, options: .backwards) {
                let rest = trimmed[range.upperBound...]
                guard !rest.isEmpty, !rest.contains(" ") else { continue }
                return String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}

/// A value that decodes as nil instead of failing the answer when the server sends something else
/// (a word instead of a number, a missing key).
@propertyWrapper
struct Lenient<T: Decodable>: Decodable {
    var wrappedValue: T?

    init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        wrappedValue = try? decoder.singleValueContainer().decode(T.self)
    }
}

extension KeyedDecodingContainer {
    func decode<T>(_ type: Lenient<T>.Type, forKey key: Key) throws -> Lenient<T> {
        (try? decodeIfPresent(type, forKey: key)) ?? Lenient(wrappedValue: nil)
    }
}

/// Entry of `source_errors`: a source that failed or is stale.
struct SourceProblem: Decodable, Hashable {
    let source: String?
    let message: String?
}

// MARK: - /api/v1/tools/weather_now

struct WeatherNow: Decodable {
    struct Location: Decodable {
        let label: String?
        let elevationM: Double?
    }

    struct Pair: Decodable {
        @Lenient var model: Double?
        @Lenient var measured: Double?
        let station: String?
        /// Gusts only: strongest measured gust of the last hour.
        @Lenient var measuredMax60min: Double?

        /// Measured value when there is one, else the model value.
        var best: (value: Double, measured: Bool)? {
            if let measured { return (measured, true) }
            if let model { return (model, false) }
            return nil
        }
    }

    struct Precipitation: Decodable {
        @Lenient var model15min: Double?
        @Lenient var measured10min: Double?
        @Lenient var measured60min: Double?
        let station: String?
    }

    struct Temperature: Decodable {
        let model: Double?
        let measured: Double?
        let station: String?
        /// The own outdoor sensor (Home Assistant), only while its last report is current.
        let local: Double?
    }

    struct Sky: Decodable {
        let model: String?
        let measured: String?
        let station: String?
    }

    struct Now: Decodable {
        let temperatureC: Temperature?
        let humidityPct: Pair?
        let windSpeedKmh: Pair?
        let windDirectionDeg: Pair?
        let windGustsKmh: Pair?
        let dewPointC: Pair?
        let pressureMslHpa: Pair?
        let cloudCoverPct: Pair?
        let visibilityM: Pair?
        let precipitationMm: Precipitation?
        let weather: Sky?
    }

    struct LocalSensor: Decodable {
        let name: String?
        let temperatureC: Double?
        let time: String?
        let ageMin: Int?
        let current: Bool?
    }

    let location: Location?
    let modelTime: String?
    let measuredTime: String?
    let now: Now?
    let localSensor: LocalSensor?
}

// MARK: - /api/v1/vorhersage/stunden

struct HoursResponse: Decodable {
    struct Hours: Decodable {
        let time: Series<String>
        let tC: Series<Double>
        let precipMm: Series<Double>
        let rainProbPct: Series<Double>
        let windKmh: Series<Double>
        let windDirDeg: Series<Double>
        let gustMaxKmh: Series<Double>
        let symbol: Series<Int>
    }

    struct Sun: Decodable {
        let date: String
        let sunrise: String?
        let sunset: String?
    }

    let hours: Hours
    let sun: [Sun]?
}

// MARK: - /api/v1/tools/weather_forecast?days=16

struct ForecastResponse: Decodable {
    struct ModelDay: Decodable {
        let tminC: Double?
        let tmaxC: Double?
        let precipMm: Double?
        let gustKmh: Double?
        let weather: String?
    }

    struct Ensemble: Decodable {
        /// P10, P50, P90
        let tmaxC: Series<Double>?
        let tminC: Series<Double>?
        let precipMm: Series<Double>?
        let rainProbPct: Double?
        let rainAnyProbPct: Double?
    }

    struct Confidence: Decodable {
        let level: String?
    }

    struct Day: Decodable {
        let date: String
        let weekday: String?
        let models: [String: ModelDay?]?
        let ecmwfEns: Ensemble?
        let confidence: Confidence?
    }

    let days: [Day]
}
