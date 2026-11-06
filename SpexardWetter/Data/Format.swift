import Foundation

/// German formatting and the server's time stamps (all local times are Europe/Berlin).
enum Fmt {
    static let zone = TimeZone(identifier: "Europe/Berlin") ?? .current
    static let locale = Locale(identifier: "de_DE")

    private static let stampParser: DateFormatter = posix("yyyy-MM-dd'T'HH:mmXXXXX")
    private static let stampParserSeconds: DateFormatter = posix("yyyy-MM-dd'T'HH:mm:ssXXXXX")
    private static let dayParser: DateFormatter = posix("yyyy-MM-dd")

    private static func posix(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone
        f.dateFormat = format
        return f
    }

    private static func german(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = zone
        f.dateFormat = format
        return f
    }

    private static let hourFormatter = german("HH")
    private static let timeFormatter = german("HH:mm")
    private static let dayFormatter = german("d.M.")
    private static let weekdayFormatter = german("EEEE")
    private static let weekdayShortFormatter = german("EE")

    /// "2026-11-04T17:00+01:00" (with or without seconds) or "2026-11-04".
    static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        return stampParser.date(from: text) ?? stampParserSeconds.date(from: text) ?? dayParser.date(from: text)
    }

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = zone
        c.locale = locale
        return c
    }

    static func hour(_ date: Date) -> String { hourFormatter.string(from: date) }
    static func time(_ date: Date?) -> String { date.map { timeFormatter.string(from: $0) } ?? "–" }
    static func dayMonth(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// "Heute", "Morgen", else "Samstag" (long) or "Sa" (short).
    static func weekday(_ date: Date, reference: Date, short: Bool = false) -> String {
        let cal = calendar
        if cal.isDate(date, inSameDayAs: reference) { return "Heute" }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: reference), cal.isDate(date, inSameDayAs: tomorrow) {
            return "Morgen"
        }
        return (short ? weekdayShortFormatter : weekdayFormatter).string(from: date)
    }

    /// "3,4°" / "−1°" with a real minus sign; nil -> "–".
    static func temp(_ value: Double?, decimals: Int = 0) -> String {
        guard let value, value.isFinite else { return "–" }
        return number(value, decimals: decimals) + "°"
    }

    static func number(_ value: Double, decimals: Int) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        let rounded = (value * pow(10, Double(decimals))).rounded() / pow(10, Double(decimals))
        let text = f.string(from: NSNumber(value: abs(rounded))) ?? "\(abs(rounded))"
        return rounded < 0 ? "\u{2212}" + text : text
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int(value.rounded())) %"
    }

    static func precip(_ value: Double?) -> String {
        guard let value else { return "–" }
        return number(value, decimals: value < 10 ? 1 : 0) + " mm"
    }

    static func wind(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int(value.rounded())) km/h"
    }

    /// Wind FROM direction in words: 270 -> "West".
    static func compass(_ degrees: Double?) -> String {
        guard let degrees else { return "" }
        let names = ["Nord", "Nordost", "Ost", "Südost", "Süd", "Südwest", "West", "Nordwest"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) + 22.5) / 45) % 8
        return names[index]
    }
}
