import Foundation
import SwiftUI

// MARK: - /api/v1/umwelt

/// Pollen (DWD, Ostwestfalen), UV index (DWD, nearest city), air quality (UBA station) and sun and
/// moon (computed by the server) in one answer. Every block is nil when its source is missing.
struct EnvironmentResponse: Decodable {
    let generatedAt: String?
    let pollen: Pollen?
    let uv: UV?
    let luft: Air?
    let astro: Astro?
    /// The server's notes on conspicuous values of this answer (pollen, UV, air).
    let hinweise: [GlossaryNote]?
    let sourceErrors: [SourceProblem]?
    let attribution: [String]?

    // MARK: pollen

    struct PollenDay: Decodable {
        let datum: String?
        /// "0", "0-1", "1" … "3" (DWD levels with half steps).
        let stufe: String?
        @Lenient var wert: Double?
        let text: String?
    }

    struct PollenType: Decodable, Identifiable {
        let id: String
        let name: String?
        let heute: PollenDay?
        let morgen: PollenDay?
        let uebermorgen: PollenDay?

        var days: [PollenDay?] { [heute, morgen, uebermorgen] }
        /// Highest level of the three days (nil when the DWD gives none).
        var maxLevel: Double? { days.compactMap { $0?.wert }.max() }
    }

    struct Pollen: Decodable {
        let region: String?
        let ausgabe: String?
        let naechsteAusgabe: String?
        let arten: [PollenType]?
    }

    // MARK: UV

    struct UVDay: Decodable {
        let datum: String?
        @Lenient var uvIndex: Double?
        /// WHO words: niedrig, mäßig, hoch, sehr hoch, extrem.
        let stufe: String?
    }

    struct UV: Decodable {
        let ort: String?
        @Lenient var entfernungKm: Double?
        let ausgabe: String?
        let naechsteAusgabe: String?
        let heute: UVDay?
        let morgen: UVDay?
        let uebermorgen: UVDay?
    }

    // MARK: air

    struct AirValue: Decodable, Identifiable {
        let id: String
        let symbol: String?
        let name: String?
        @Lenient var wert: Double?
        let einheit: String?
        /// UBA class of this pollutant (0 sehr gut … 4 sehr schlecht).
        @Lenient var index: Int?
        let text: String?
    }

    /// The last 24 hours (index-aligned with `zeit`; nil = not measured).
    struct AirHistory: Decodable {
        let zeit: [String]?
        let index: [Int?]?
        let pm10: [Double?]?
        let pm25: [Double?]?
        let o3: [Double?]?
        let no2: [Double?]?
    }

    struct Air: Decodable {
        let station: String?
        let stationCode: String?
        @Lenient var entfernungKm: Double?
        /// End of the measured hour, local time as delivered ("2026-11-19T21:00").
        let stand: String?
        @Lenient var index: Int?
        let text: String?
        /// The station does not measure every pollutant of the index.
        let unvollstaendig: Bool?
        /// The last measured hour is older than six hours (the server then gives no note).
        let veraltet: Bool?
        let werte: [AirValue]?
        let verlauf: AirHistory?
    }

    // MARK: sun and moon

    struct SunDay: Decodable, Identifiable {
        let datum: String
        let aufgang: String?
        let untergang: String?
        @Lenient var tageslaengeMin: Double?

        var id: String { datum }
    }

    struct Sun: Decodable {
        let aufgang: String?
        let untergang: String?
        let mittag: String?
        @Lenient var hoechststandGrad: Double?
        @Lenient var tageslaengeMin: Double?
        /// Day length minus the day before (minutes).
        @Lenient var aenderungMin: Double?
        /// Civil twilight (sun 6° below the horizon).
        let daemmerungBeginn: String?
        let daemmerungEnde: String?
        let tage: [SunDay]?
    }

    struct MoonPhase: Decodable, Hashable {
        let phase: String?
        let zeit: String?
    }

    struct Moon: Decodable {
        let phase: String?
        @Lenient var beleuchtungPct: Double?
        let zunehmend: Bool?
        @Lenient var alterTage: Double?
        let beleuchtungUm: String?
        let aufgang: String?
        let untergang: String?
        let naechstePhasen: [MoonPhase]?
    }

    struct Astro: Decodable {
        let datum: String?
        let sonne: Sun?
        let mond: Moon?
    }
}

extension Endpoint {
    static let environment = Endpoint(path: "/api/v1/umwelt", mock: "mock_umwelt")
}

/// Colours and words of the scales the sources use (DWD pollen levels, WHO UV scale, UBA index).
enum EnvironmentScale {
    /// DWD pollen level 0 … 3 (half steps in between).
    static func pollenColor(_ value: Double?) -> Color {
        guard let v = value else { return .white.opacity(0.12) }
        switch v {
        case ..<0.25: return Color(red: 0.45, green: 0.80, blue: 0.55).opacity(0.55)
        case ..<0.75: return Color(red: 0.75, green: 0.88, blue: 0.40)
        case ..<1.25: return Color(red: 1.0, green: 0.86, blue: 0.30)
        case ..<1.75: return Color(red: 1.0, green: 0.70, blue: 0.25)
        case ..<2.25: return Color(red: 1.0, green: 0.52, blue: 0.20)
        case ..<2.75: return Color(red: 0.95, green: 0.32, blue: 0.22)
        default: return Color(red: 0.80, green: 0.16, blue: 0.26)
        }
    }

    /// WHO UV index colours: green 0–2, yellow 3–5, orange 6–7, red 8–10, violet from 11.
    static func uvColor(_ index: Double?) -> Color {
        guard let i = index else { return .white.opacity(0.2) }
        switch i {
        case ..<2.5: return Color(red: 0.36, green: 0.72, blue: 0.36)
        case ..<5.5: return Color(red: 0.98, green: 0.84, blue: 0.20)
        case ..<7.5: return Color(red: 0.98, green: 0.55, blue: 0.15)
        case ..<10.5: return Color(red: 0.88, green: 0.18, blue: 0.16)
        default: return Color(red: 0.55, green: 0.30, blue: 0.75)
        }
    }

    /// UBA air quality index 0 sehr gut … 4 sehr schlecht (colours of the UBA scale).
    static func airColor(_ index: Int?) -> Color {
        switch index {
        case 0: return Color(red: 0.31, green: 0.78, blue: 0.85)
        case 1: return Color(red: 0.48, green: 0.82, blue: 0.62)
        case 2: return Color(red: 0.98, green: 0.84, blue: 0.27)
        case 3: return Color(red: 0.93, green: 0.36, blue: 0.27)
        case 4: return Color(red: 0.62, green: 0.12, blue: 0.22)
        default: return .white.opacity(0.2)
        }
    }

    /// SF Symbol of the moon phase ("zunehmender Mond" -> waxing gibbous).
    static func moonSymbol(_ phase: String?, waxing: Bool?) -> String {
        let p = (phase ?? "").lowercased()
        if p.contains("neumond") { return "moonphase.new.moon" }
        if p.contains("vollmond") { return "moonphase.full.moon" }
        if p.contains("erstes viertel") { return "moonphase.first.quarter" }
        if p.contains("letztes viertel") { return "moonphase.last.quarter" }
        if p.contains("sichel") { return waxing == false ? "moonphase.waning.crescent" : "moonphase.waxing.crescent" }
        return waxing == false ? "moonphase.waning.gibbous" : "moonphase.waxing.gibbous"
    }

    /// "8 h 38 min".
    static func duration(_ minutes: Double?) -> String {
        guard let minutes else { return "–" }
        let m = Int(minutes.rounded())
        return "\(m / 60) h \(m % 60) min"
    }

    /// "2,9 min kürzer als gestern" / "1,2 min länger als gestern".
    static func change(_ minutes: Double?) -> String? {
        guard let minutes else { return nil }
        if abs(minutes) < 0.05 { return "so lang wie gestern" }
        return Fmt.number(abs(minutes), decimals: 1) + " min " + (minutes < 0 ? "kürzer" : "länger") + " als gestern"
    }
}
