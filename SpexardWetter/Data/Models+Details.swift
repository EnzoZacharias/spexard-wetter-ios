import Foundation

// MARK: - /api/v1/gefahren/matrix

/// Hourly attention levels of local hazards from the DWD MOSMIX station (not official warnings).
struct HazardMatrixResponse: Decodable {
    struct Station: Decodable {
        let id: String?
        let name: String?
        @Lenient var entfernungKm: Double?
        @Lenient var hoeheM: Double?
        let lauf: String?
        let prognoseBis: String?
    }

    struct Row: Decodable, Identifiable {
        let id: String
        let name: String
        let einheit: String?
        let verfuegbar: Bool?
        let hinweis: String?
        let stufen: Series<Int>?
        let werte: Series<Double>?
        let texte: Series<String>?
        @Lenient var maxStufe: Int?
        let maxStufeText: String?
        let ersteStunde: String?
        let letzteStunde: String?
        let spitzeStunde: String?
    }

    let generatedAt: String?
    let station: Station?
    let time: [String]
    let stufenNamen: [String]?
    let zeilen: [Row]
    let nichtVerfuegbar: [String: String]?
    let sourceErrors: [SourceProblem]?
}

// MARK: - /api/v1/messwerte/verlauf?stunden=24|48|72

/// Measured history of the DWD stations around the location.
struct MeasurementsResponse: Decodable {
    struct Station: Decodable, Identifiable {
        let id: String
        let name: String?
        @Lenient var distanceKm: Double?
        let direction: String?
        @Lenient var heightM: Double?
        let lastObs: String?
        /// Measure id (camelCase of the server key, e.g. "windSpeedKmh") -> hourly values.
        let series: [String: Series<Double>]?
    }

    struct Extreme: Decodable {
        @Lenient var value: Double?
        let time: String?
        let station: String?
    }

    struct Precipitation: Decodable {
        @Lenient var value: Double?
        @Lenient var hours: Int?
        @Lenient var expected: Int?
        let until: String?
        let station: String?
    }

    struct Normal: Decodable {
        @Lenient var tmaxC: Double?
        @Lenient var tminC: Double?
        @Lenient var precipMm: Double?
        @Lenient var wetDayPct: Double?
        let label: String?
    }

    struct Today: Decodable {
        let date: String?
        let tmax: Extreme?
        let tmin: Extreme?
        let gustMax: Extreme?
        let precipitation: Precipitation?
        let sunshine: Extreme?
        let normal: Normal?
    }

    struct Tendency: Decodable {
        @Lenient var changeHpa: Double?
        @Lenient var toHpa: Double?
        let text: String?
        let station: String?
        let from: String?
        let to: String?
    }

    let generatedAt: String?
    @Lenient var stunden: Int?
    let time: [String]
    let stations: [Station]
    /// Measure id -> station id that delivers it.
    let primary: [String: String]?
    let pressureTendency: Tendency?
    let today: Today?
    let sun: [HoursResponse.Sun]?
    let sourceErrors: [SourceProblem]?

    /// Hourly values of a measure from its primary station ("temperature_c").
    func series(_ measure: String) -> (station: Station, values: [Double?])? {
        let key = APIClient.camelCase(measure)
        let stationId = primary?[key]
        let station = stations.first { $0.id == stationId && $0.series?[key] != nil }
            ?? stations.first { $0.series?[key] != nil }
        guard let station, let s = station.series?[key] else { return nil }
        return (station, s.expanded(time.count))
    }
}

// MARK: - /api/v1/meteogramm/modell?modell=...

/// Hourly forecast of one weather model at the location.
struct MeteogramResponse: Decodable {
    struct Model: Decodable {
        struct Step: Decodable {
            let from: String?
            @Lenient var hours: Int?
        }

        let id: String?
        let label: String?
        @Lenient var heightM: Double?
        let dataUntil: String?
        /// From `from` on the model computes only every `hours` hours.
        let steps: [Step]?
    }

    struct Hourly: Decodable {
        let time: [String]
        let tC: Series<Double>?
        let dewPointC: Series<Double>?
        let rhPct: Series<Double>?
        let precipMm: Series<Double>?
        let snowCm: Series<Double>?
        let cloudPct: Series<Double>?
        let cloudLowPct: Series<Double>?
        let cloudMidPct: Series<Double>?
        let cloudHighPct: Series<Double>?
        let pressureHpa: Series<Double>?
        let windKmh: Series<Double>?
        let windDirDeg: Series<Double>?
        let gustKmh: Series<Double>?
        let capeJkg: Series<Double>?
        let sunMin: Series<Double>?
        let weatherCode: Series<Int>?
    }

    let generatedAt: String?
    let model: Model?
    let hourly: Hourly
    let days: [HoursResponse.Sun]?
    let sourceErrors: [SourceProblem]?
}
