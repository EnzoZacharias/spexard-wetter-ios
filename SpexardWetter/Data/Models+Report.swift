import Foundation

// MARK: - /api/v1/wetterbericht?art=heute|wochenende|woche

/// The written weather report of the server (composed from the DWD texts and the models).
struct ReportResponse: Decodable {
    struct Quote: Decodable, Hashable {
        let text: String
        let quelle: String?
    }

    struct Link: Decodable, Hashable {
        let href: String
        let text: String
    }

    struct Question: Decodable, Hashable {
        let frage: String
        let antwort: String
        let grundlage: String?
        let link: Link?
    }

    struct Kpi: Decodable, Hashable {
        let label: String
        let wert: String
        /// "hinweis" | "warnung"
        let ton: String?
    }

    struct Spark: Decodable {
        let time: [String]
        let tC: Series<Double>?
        let regenPct: Series<Double>?
        let quelle: String?
    }

    struct Period: Decodable {
        let von: String?
        let bis: String?
    }

    struct Section: Decodable, Identifiable {
        let id: String
        let titel: String
        let absaetze: [String]?
        let fach: [String]?
        let zitate: [Quote]?
        let fragen: [Question]?
        let kennzahlen: [Kpi]?
        let grundlage: [String]?
        let zeitraum: Period?
        let konfidenz: String?
        let verlauf: Spark?
        let links: [Link]?
        let hinweis: String?
    }

    struct Missing: Decodable, Identifiable {
        let id: String
        let titel: String
        let grund: String?
    }

    struct Location: Decodable {
        let label: String?
    }

    let art: String?
    let titel: String?
    let untertitel: String?
    let generatedAt: String?
    let stand: String?
    let location: Location?
    let schlagzeile: String?
    let kurzfassung: [String]?
    let abschnitte: [Section]
    let fehlendeAbschnitte: [Missing]?
    let grundlage: [String]?
    let sourceErrors: [SourceProblem]?
}

enum ReportWords {
    /// Time span of a section: same day "Mi 18–22 Uhr", overnight "Mi 22 – Do 7 Uhr",
    /// several days "Sa 7.11. – Di 10.11." (an end at midnight belongs to the day before).
    static func period(_ von: String?, _ bis: String?) -> String? {
        guard let a = Fmt.parse(von), let b = Fmt.parse(bis), b > a else { return nil }
        let cal = Fmt.calendar
        let startHour = cal.component(.hour, from: a)
        let endHour = cal.component(.hour, from: b)
        let last = b.addingTimeInterval(-1)
        let wholeDays = startHour == 0 && endHour == 0
        if !wholeDays && b.timeIntervalSince(a) <= 24 * 3600 {
            if cal.isDate(a, inSameDayAs: last) {
                return "\(Fmt.weekdayShort(a)) \(startHour)–\(endHour == 0 ? 24 : endHour) Uhr"
            }
            return "\(Fmt.weekdayShort(a)) \(startHour) – \(Fmt.weekdayShort(b)) \(endHour) Uhr"
        }
        if cal.isDate(a, inSameDayAs: last) { return "\(Fmt.weekdayShort(a)) \(Fmt.dayMonth(a))" }
        return "\(Fmt.weekdayShort(a)) \(Fmt.dayMonth(a)) – \(Fmt.weekdayShort(last)) \(Fmt.dayMonth(last))"
    }

    /// "hoch" / "mittel" / "niedrig" from the report's confidence words.
    static func confidenceLevel(_ word: String?) -> String? {
        guard let w = word?.lowercased(), !w.isEmpty else { return nil }
        if w.hasPrefix("hoch") { return "hoch" }
        if w.hasPrefix("mittel") { return "mittel" }
        if w.hasPrefix("niedrig") || w.hasPrefix("sehr niedrig") || w.hasPrefix("minimal") || w.hasPrefix("gering") { return "niedrig" }
        return nil
    }
}
