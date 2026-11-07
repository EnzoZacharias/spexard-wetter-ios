import Foundation

// MARK: - /api/v1/historie?zeitraum=tage|wochen|monate|jahre

/// The past at the location: the own outdoor sensor (Home Assistant) and the DWD daily climate
/// values of the stations around, grouped into days, weeks, months or years (newest last).
struct HistoryResponse: Decodable {
    let generatedAt: String?
    let zeitraum: String?
    let zeitraeume: [String]?
    let garten: Garden?
    let station: StationBlock?
    let vergleich: [Comparison]?
    let sourceErrors: [SourceProblem]?
    let attribution: [String]?

    /// DWD climatological days ("Kenntage") of a period.
    struct Kenntage: Decodable, Hashable {
        let frosttage: Int?
        let eistage: Int?
        let sommertage: Int?
        let heisseTage: Int?
        let tropennaechte: Int?
    }

    /// The normal 1991–2020 (ERA5) of the same days.
    struct Normal: Decodable, Hashable {
        let tmittelC: Double?
        let tmaxC: Double?
        let tminC: Double?
        let niederschlagMm: Double?
    }

    struct Garden: Decodable {
        let name: String?
        /// First day of the sensor at its place.
        let seit: String?
        let tageMitDaten: Int?
        let tageVollstaendig: Int?
        let heute: Today?
        let perioden: [GardenPeriod]?
        let rekorde: GardenRecords?
        /// One sentence on the newest period with a deviation from the normal.
        let satz: String?
    }

    struct Today: Decodable {
        let datum: String?
        let tminC: Double?
        let tminZeit: String?
        let tmaxC: Double?
        let tmaxZeit: String?
        let stunden: Int?
    }

    struct GardenPeriod: Decodable, Identifiable {
        let key: String
        let label: String?
        let von: String?
        let bis: String?
        let tminC: Double?
        let tminZeit: String?
        /// false: only the hour of the lowest value is known (hourly statistics).
        let tminGenau: Bool?
        let tmaxC: Double?
        let tmaxZeit: String?
        let tmaxGenau: Bool?
        let tmittelC: Double?
        /// Days: hours with data, `heute`.
        let stunden: Int?
        let heute: Bool?
        /// Longer periods: complete days of all days so far.
        let tageVollstaendig: Int?
        let tage: Int?
        let vollstaendig: Bool?
        let spanneK: Double?
        let kenntage: Kenntage?
        let normal: Normal?
        let abweichungK: Double?

        var id: String { key }
    }

    struct Record: Decodable {
        let datum: String?
        let wertC: Double?
        let wertK: Double?
        let zeit: String?
        let genau: Bool?
    }

    struct GardenRecords: Decodable {
        let hoechstwert: Record?
        let tiefstwert: Record?
        let waermsterTag: Record?
        let kaeltesterTag: Record?
        let groessteSpanne: Record?
        let tage: Int?
        let seit: String?
    }

    struct Station: Decodable, Identifiable {
        let id: String
        let name: String?
        let hoeheM: Double?
        let entfernungKm: Double?
        let richtung: String?
        /// Values this station gives (`tmax`, `rr_mm`, `fx_kmh` ...).
        let werte: [String]?
        /// Values it fills in on days the main station has none.
        let ersatzFuer: [String]?
    }

    struct StationPeriod: Decodable, Identifiable {
        let key: String
        let label: String?
        let von: String?
        let bis: String?
        let tminC: Double?
        let tminDatum: String?
        let tmaxC: Double?
        let tmaxDatum: String?
        let tmittelC: Double?
        let niederschlagMm: Double?
        let niederschlagstage: Int?
        let niederschlagNormalMm: Double?
        let boeMaxKmh: Double?
        let boeMaxDatum: String?
        let windMittelKmh: Double?
        let schneeMaxCm: Double?
        let schneedeckentage: Int?
        let bodenfrosttage: Int?
        let kenntage: Kenntage?
        let tage: Int?
        let tageTemperatur: Int?
        let normal: Normal?
        let abweichungK: Double?

        var id: String { key }
    }

    struct StationValue: Decodable {
        let wert: Double?
        let datum: String?
    }

    struct StationRecords: Decodable {
        let hoechstwertC: StationValue?
        let tiefstwertC: StationValue?
        let bodenfrostTiefstC: StationValue?
        let niederschlagTagMm: StationValue?
        let boeKmh: StationValue?
        let schneeCm: StationValue?
        let seit: String?
        let bis: String?
    }

    struct StationBlock: Decodable {
        let stationen: [Station]?
        let seit: String?
        let bis: String?
        let perioden: [StationPeriod]?
        let rekorde: StationRecords?
        /// Days with a value of the replacement station.
        let ersatzTage: Int?
        let hinweis: String?
    }

    /// Garden minus station (K) on days with both.
    struct Comparison: Decodable, Identifiable {
        let key: String
        let label: String?
        let von: String?
        let bis: String?
        let tage: Int?
        let tminDiffK: Double?
        let tmaxDiffK: Double?

        var id: String { key }
    }
}

enum HistoryUnit: String, CaseIterable, Identifiable {
    case tage, wochen, monate, jahre

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tage: return "Tage"
        case .wochen: return "Wochen"
        case .monate: return "Monate"
        case .jahre: return "Jahre"
        }
    }

    var endpoint: Endpoint {
        Endpoint(path: "/api/v1/historie?zeitraum=\(rawValue)", mock: "mock_historie_\(rawValue)")
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .tage: return .day
        case .wochen: return .weekOfYear
        case .monate: return .month
        case .jahre: return .year
        }
    }
}
