import Foundation

/// A series from the server (`[1.2, null, 3.4]`). The server may collapse a constant series into a
/// sentence ("0.0 mm in allen Stunden"); such a value decodes as an empty series instead of failing
/// the whole answer.
struct Series<T: Decodable>: Decodable {
    let values: [T?]

    init(values: [T?] = []) { self.values = values }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        values = (try? container.decode([T?].self)) ?? []
    }

    subscript(index: Int) -> T? { values.indices.contains(index) ? values[index] : nil }
    var count: Int { values.count }
}

// MARK: - /api/v1/tools/weather_now

struct WeatherNow: Decodable {
    struct Location: Decodable {
        let label: String?
        let elevationM: Double?
    }

    struct Pair: Decodable {
        let model: Double?
        let measured: Double?
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
