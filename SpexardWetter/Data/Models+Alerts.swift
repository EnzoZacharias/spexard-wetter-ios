import Foundation

// MARK: - /api/v1/tools/weather_alerts

/// Official DWD warnings for the municipal warn cell (`weather_alerts`, block `warnungen`).
struct AlertsResponse: Decodable {
    let generatedAt: String?
    let warnungen: WarningBlock?
    let sourceErrors: [SourceProblem]?
}

struct WarningBlock: Decodable {
    /// "keine Warnungen" (normal), "1 Warnung (höchste Stufe 2), ..." or "unbekannt ..." (source down).
    let status: String?
    @Lenient var hoechsteStufe: Int?
    @Lenient var anzahlWarnungen: Int?
    @Lenient var anzahlVorabinformationen: Int?
    let gebiet: String?
    let quelle: String?
    let hinweis: String?
    let hinweisVeraltet: String?
    let warnungen: [DwdWarning]?
    let vorabinformationen: [DwdWarning]?

    var warnings: [DwdWarning] { warnungen ?? [] }
    var preWarnings: [DwdWarning] { vorabinformationen ?? [] }

    /// False when the warning source did not answer.
    var known: Bool {
        guard let status, !status.isEmpty else { return false }
        return !status.hasPrefix("unbekannt")
    }

    /// The warning for the banner: the first warning (the server sorts by level), else the first
    /// Vorabinformation.
    var top: DwdWarning? { warnings.first ?? preWarnings.first }
    var topIsPre: Bool { warnings.isEmpty && !preWarnings.isEmpty }
    var totalCount: Int { warnings.count + preWarnings.count }
}

struct DwdWarning: Decodable, Identifiable {
    let ereignis: String?
    @Lenient var stufe: Int?
    let stufeText: String?
    /// "aktiv" | "erwartet"
    let status: String?
    let beginn: String?
    let ende: String?
    let schlagzeile: String?
    let beschreibung: String?
    let hinweise: String?
    @Lenient var hoeheAbM: Double?
    @Lenient var hoeheBisM: Double?

    var id: String { [ereignis, beginn, ende, schlagzeile].compactMap { $0 }.joined(separator: "|") }

    var title: String { schlagzeile ?? ereignis.map { $0.capitalized } ?? "Warnung des DWD" }

    /// "bis morgen 10:43 Uhr", "ab heute 22:00 Uhr", "ohne Endzeit" (like the website's banner).
    func whenText(reference: Date) -> String {
        if status == "erwartet", let start = Fmt.parse(beginn) {
            return "ab " + Fmt.relativeDateTime(start, reference: reference)
        }
        if let end = Fmt.parse(ende) {
            return "bis " + Fmt.relativeDateTime(end, reference: reference)
        }
        return "ohne Endzeit"
    }
}

// MARK: - /api/v1/tools/rain_nowcast

/// DWD radar nowcast at the location: measured 5-minute steps plus the two-hour forecast.
struct NowcastResponse: Decodable {
    struct Summary: Decodable {
        let rainingNow: Bool?
        let rainWithin3kmNow: Bool?
        let radarAnalysis: String?
        @Lenient var analysisAgeMin: Double?
        let nowcastUntil: String?
        /// ISO time, or words when the phase reaches beyond the window ("vor Fensterbeginn").
        let rainStart: String?
        let rainEnd: String?
        @Lenient var expectedMm: Double?
        @Lenient var peakMmH: Double?
        let peakIntensity: String?
        let rainNearbyInNowcast: Bool?
        let text: String?
    }

    struct Radar: Decodable {
        let time: [String]
        let nowcastFrom: String?
        let pointMmH: Series<Double>?
        let areaMaxMmH: Series<Double>?
    }

    let generatedAt: String?
    let summary: Summary?
    let radar5min: Radar?
    let sourceErrors: [SourceProblem]?

    /// "Es regnet bis etwa 18:20", "Regen ab etwa 17:55", "Trocken bis 19:35" (website rule).
    var headline: String {
        guard let s = summary else { return "Keine Radardaten" }
        if s.rainingNow == true {
            if let end = Fmt.parse(s.rainEnd) { return "Es regnet bis etwa \(Fmt.time(end))" }
            return "Es regnet"
        }
        if let start = Fmt.parse(s.rainStart) { return "Regen ab etwa \(Fmt.time(start))" }
        if let until = Fmt.parse(s.nowcastUntil) { return "Trocken bis \(Fmt.time(until))" }
        return "Trocken"
    }

    struct Step: Identifiable {
        let id: Int
        /// End of the 5-minute interval.
        let end: Date
        let mmh: Double?
        let forecast: Bool
    }

    var steps: [Step] {
        guard let radar = radar5min else { return [] }
        let values = radar.pointMmH?.expanded(radar.time.count) ?? []
        let from = Fmt.parse(radar.nowcastFrom)
        var out: [Step] = []
        for (i, text) in radar.time.enumerated() {
            guard let date = Fmt.parse(text) else { continue }
            let value = values.indices.contains(i) ? values[i] : nil
            out.append(Step(id: i, end: date, mmh: value, forecast: from.map { date >= $0 } ?? false))
        }
        return out
    }
}
