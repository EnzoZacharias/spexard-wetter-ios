import Foundation

// MARK: - /api/v1/modelle/stunden

/// Hourly values of the deterministic models side by side plus their spread.
struct ModelHoursResponse: Decodable {
    struct Info: Decodable {
        let label: String?
    }

    struct ModelSeries: Decodable {
        let tC: Series<Double>?
        let precipMm: Series<Double>?
        let cloudPct: Series<Double>?
        let windKmh: Series<Double>?
        let gustKmh: Series<Double>?
    }

    struct Summary: Decodable {
        let tC: Series<Double>?
        let tMinC: Series<Double>?
        let tMaxC: Series<Double>?
        let precipMm: Series<Double>?
        let precipMaxMm: Series<Double>?
        let wetModels: Series<String>?
        let windKmh: Series<Double>?
        let gustMaxKmh: Series<Double>?
        let cloudPct: Series<Double>?
    }

    struct Day: Decodable {
        let date: String
        @Lenient var tminC: Double?
        @Lenient var tmaxC: Double?
        @Lenient var precipMm: Double?
        @Lenient var gustMaxKmh: Double?
        @Lenient var cloudMeanPct: Double?
    }

    let generatedAt: String?
    let time: [String]
    let modelsInfo: [String: Info]?
    let models: [String: ModelSeries]
    let summary: Summary?
    let days: [String: [Day]]?
    let sourceErrors: [SourceProblem]?

    /// Model ids in a fixed order (ICON, ECMWF, GFS, UKMO, AROME, then the rest).
    var modelIds: [String] {
        let order = ["icon", "ecmwf", "gfs", "ukmo", "arome"]
        return models.keys.sorted { a, b in
            let ia = order.firstIndex(of: a) ?? order.count
            let ib = order.firstIndex(of: b) ?? order.count
            return ia == ib ? a < b : ia < ib
        }
    }

    func label(_ id: String) -> String {
        ModelNames.short(id, long: modelsInfo?[id]?.label)
    }
}

enum ModelNames {
    /// "icon" -> "ICON", "ecmwf" -> "ECMWF" (the server's long label as fallback).
    static func short(_ id: String, long: String? = nil) -> String {
        switch id.lowercased() {
        case "icon": return "ICON"
        case "icond2", "icon_d2": return "ICON-D2"
        case "ecmwf": return "ECMWF"
        case "gfs": return "GFS"
        case "ukmo": return "UKMO"
        case "arome": return "AROME"
        case "gefs": return "GEFS"
        case "mosmix": return "MOSMIX"
        default: return long ?? id.uppercased()
        }
    }
}

// MARK: - /api/v1/ensembles/*

struct EnsembleTempResponse: Decodable {
    struct Model: Decodable {
        let id: String?
        let label: String?
        @Lenient var members: Int?
    }

    let generatedAt: String?
    let model: Model?
    let time: [String]
    let members: [Series<Double>]?
    let min: Series<Double>?
    let p10: Series<Double>?
    let p50: Series<Double>?
    let p90: Series<Double>?
    let max: Series<Double>?
    let sourceErrors: [SourceProblem]?
}

struct EnsembleRainResponse: Decodable {
    struct Threshold: Decodable {
        let key: String?
        let label: String?
        @Lenient var value: Double?
    }

    let generatedAt: String?
    let label: String?
    @Lenient var membersCount: Int?
    let thresholds: [Threshold]?
    let time: [String]
    let pct: [Series<Double>]?
    let p50: Series<Double>?
    let max: Series<Double>?
    let sourceErrors: [SourceProblem]?
}

struct EnsembleDaysResponse: Decodable {
    struct Certainty: Decodable, Identifiable {
        let date: String
        let weekday: String?
        let source: String?
        @Lenient var tmaxP10: Double?
        @Lenient var tmaxP50: Double?
        @Lenient var tmaxP90: Double?
        @Lenient var tmaxWidthK: Double?
        /// "eng", "mittel", "breit" ...
        let spread: String?
        @Lenient var gefsDeltaK: Double?
        let agreement: String?
        @Lenient var rain1mmPct: Double?
        let rainWords: String?

        var id: String { date }
    }

    let generatedAt: String?
    let certainty: [Certainty]?
    let sourceErrors: [SourceProblem]?
}

// MARK: - /api/v1/tools/weather_trend

struct TrendResponse: Decodable {
    struct Confidence: Decodable {
        let level: String?
        let why: String?
    }

    struct Block: Decodable {
        let days: String?
        let from: String?
        let to: String?
        @Lenient var ecmwfTmaxAnomalyK: Double?
        @Lenient var gefsTmaxAnomalyK: Double?
        @Lenient var ecmwfRainProbPct: Double?
        @Lenient var gefsRainProbPct: Double?
        @Lenient var normalRainProbPct: Double?
        let confidence: Confidence?
    }

    struct EnsembleDay: Decodable {
        /// P10, P50, P90
        let tmaxC: Series<Double>?
        let tminC: Series<Double>?
        let precipMm: Series<Double>?
        @Lenient var rainProbPct: Double?
    }

    struct Normal: Decodable {
        @Lenient var tmaxC: Double?
        @Lenient var tminC: Double?
        @Lenient var precipMm: Double?
        @Lenient var rainProbPct: Double?
    }

    struct Day: Decodable, Identifiable {
        let date: String
        let weekday: String?
        @Lenient var day: Int?
        let ecmwf: EnsembleDay?
        let gefs: EnsembleDay?
        let normal: Normal?

        var id: String { date }
    }

    struct Week: Decodable, Identifiable {
        let from: String?
        let to: String?
        let days: String?
        @Lenient var tMeanC: Double?
        @Lenient var tAnomalyK: Double?
        @Lenient var pWarmerPct: Double?
        @Lenient var precipWeekMm: Double?
        @Lenient var precipAnomalyMm: Double?
        @Lenient var pWetterPct: Double?
        let signal: String?
        let confidence: Confidence?

        var id: String { (from ?? "") + (to ?? "") }
    }

    let generatedAt: String?
    let blocks: [Block]?
    let days816: [Day]?
    let weeks: [Week]?
    let sourceErrors: [SourceProblem]?
}

// MARK: - /api/v1/verifikation/auswertung?tage=7|30|90

struct VerificationResponse: Decodable {
    struct Rank: Decodable, Identifiable {
        let model: String
        let name: String?
        @Lenient var rang: Int?
        @Lenient var mae: Double?
        @Lenient var bias: Double?
        @Lenient var n: Int?
        let lowN: Bool?
        let biasText: String?

        var id: String { model }
    }

    struct Variable: Decodable, Identifiable {
        let key: String
        let label: String?
        let fehlerEinheit: String?
        let aussage: String?
        let rangliste: [Rank]?
        let auffaellig: [String]?
        let station: String?

        var id: String { key }
    }

    struct Period: Decodable {
        let von: String?
        let bis: String?
    }

    let generatedAt: String?
    @Lenient var tage: Int?
    let zeitraum: Period?
    let hatDaten: Bool?
    let hinweis: String?
    let aussagen: [String]?
    let variablen: [Variable]?
    let sourceErrors: [SourceProblem]?
}

// MARK: - /api/v1/status/uebersicht

struct StatusResponse: Decodable {
    struct Light: Decodable {
        /// "gruen" | "gelb" | "rot"
        let stufe: String?
        let text: String?
        let gruende: [String]?
    }

    struct Server: Decodable {
        let version: String?
        let gestartet: String?
        @Lenient var laufzeitH: Double?
    }

    struct Budget: Decodable {
        @Lenient var verbraucht: Double?
        @Lenient var anfragen: Int?
        @Lenient var softCap: Double?
        @Lenient var freeLimit: Double?
        @Lenient var anteilSoftPct: Double?
        @Lenient var abgelehnt: Int?
        let pauseBis: String?
    }

    struct Source: Decodable, Identifiable {
        let gruppe: String?
        let name: String?
        let beschreibung: String?
        let takt: String?
        @Lenient var alterMin: Double?
        let bewertung: String?

        var id: String { (gruppe ?? "") + (name ?? "") }
    }

    struct Job: Decodable, Identifiable {
        let id: String
        let name: String?
        let naechster: String?
        let letzter: String?
        let ausgeblieben: String?
    }

    let generatedAt: String?
    let ampel: Light?
    let server: Server?
    let budget: Budget?
    let quellen: [Source]?
    let jobs: [Job]?
    let sourceErrors: [SourceProblem]?
}
