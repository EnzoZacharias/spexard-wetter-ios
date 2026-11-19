import Foundation

/// The sentences Siri and the Shortcuts app answer with. Built only from the server's answers (no
/// own meteorology); the app shows the same sentences under Mehr → Siri & Kurzbefehle.
enum SiriAnswers {
    /// "5,4" / "minus 0,5" (spoken, so no minus sign that a voice might skip).
    static func spoken(_ value: Double, decimals: Int = 1) -> String {
        value < 0 ? "minus " + Fmt.number(-value, decimals: decimals) : Fmt.number(value, decimals: decimals)
    }

    /// " (gespeicherter Stand von 17:30, der Wetterserver antwortet gerade nicht)" for stored answers.
    static func offlineNote(_ date: Date, offline: Bool) -> String {
        offline ? " Das ist der gespeicherte Stand von \(Fmt.time(date)) Uhr, der Wetterserver antwortet gerade nicht." : ""
    }

    static let noServer = "Der Wetterserver ist gerade nicht erreichbar."

    // MARK: garden

    /// "Im Garten sind es 5,4 Grad, gemessen um 17:30 Uhr. Heute bisher zwischen minus 0,5 und 1,4 Grad."
    static func garden(now: WeatherNow, today: HistoryWidgetData?, stand: Date, offline: Bool) -> String {
        var text: String
        if let sensor = now.localSensor, sensor.current == true, let t = sensor.temperatureC {
            text = "Im Garten sind es \(spoken(t)) Grad, gemessen um \(Fmt.time(Fmt.parse(sensor.time))) Uhr."
        } else {
            let fallback = WeatherDerived.currentTemp(now)
            if let sensor = now.localSensor, let age = sensor.ageMin, age > 0 {
                text = "Der Gartensensor hat seit \(age) Minuten nichts gemeldet."
            } else {
                text = "Vom Gartensensor gibt es gerade keinen Wert."
            }
            if let t = fallback.value {
                switch fallback.source {
                case .station:
                    text += " An der DWD-Station \(fallback.name ?? "") sind es \(spoken(t)) Grad (\(Fmt.time(fallback.time)) Uhr)."
                case .model:
                    text += " Das Modell ICON-D2 rechnet mit \(spoken(t)) Grad."
                default:
                    break
                }
            }
        }
        if let low = today?.todayLow?.celsius, let high = today?.todayHigh?.celsius {
            text += " Heute bisher zwischen \(spoken(low)) und \(spoken(high)) Grad."
        }
        return text + offlineNote(stand, offline: offline)
    }

    // MARK: rain

    /// The radar nowcast in one or two sentences ("Trocken: kein Niederschlag am Standort bis 19:35 erwartet.").
    static func rain(_ nowcast: NowcastResponse, stand: Date, offline: Bool) -> String {
        var text: String
        if let sentence = nowcast.summary?.text, !sentence.isEmpty {
            text = sentence
        } else {
            text = nowcast.headline + "."
        }
        if !text.hasSuffix(".") { text += "." }
        return text + offlineNote(stand, offline: offline)
    }

    // MARK: warnings

    /// "Amtliche Warnung des DWD vor Sturmböen, Stufe 2, bis morgen 10:43 Uhr. Dazu 1 weitere."
    static func warnings(_ alerts: AlertsResponse, reference: Date, stand: Date, offline: Bool) -> String {
        guard let block = alerts.warnungen, block.known else {
            return "Die Warnungen des DWD sind gerade nicht abrufbar."
        }
        guard let top = block.top else {
            let area = block.gebiet.map { " für \($0)" } ?? ""
            return "Keine amtliche Warnung des DWD\(area)." + offlineNote(stand, offline: offline)
        }
        let what = top.ereignis.map { $0.capitalized } ?? top.title
        var text: String
        if block.topIsPre {
            text = "Vorabinformation des DWD: \(what), \(top.whenText(reference: reference))."
        } else {
            let level = top.stufe.map { ", Stufe \($0)" } ?? ""
            text = "Amtliche Warnung des DWD vor \(what)\(level), \(top.whenText(reference: reference))."
        }
        let more = block.totalCount - 1
        if more > 0 { text += more == 1 ? " Dazu eine weitere." : " Dazu \(more) weitere." }
        return text + offlineNote(stand, offline: offline)
    }

    // MARK: weather

    /// "In Spexard 5 Grad, bewölkt. Heute 3 bis 9 Grad. Trocken bis 19:35."
    static func weather(_ s: WidgetSnapshot) -> String {
        var parts: [String] = []
        var first = "In \(s.shortPlace)"
        if let t = s.temp { first += " \(spoken(t, decimals: 0)) Grad" }
        if let sky = s.sky { first += ", \(sky.lowercased())" }
        parts.append(first + ".")
        if let lo = s.min, let hi = s.max {
            parts.append("Heute \(spoken(lo, decimals: 0)) bis \(spoken(hi, decimals: 0)) Grad.")
        }
        if let rain = s.rainHeadline {
            parts.append(rain + ".")
        }
        if let warning = s.warningTitle {
            parts.append((s.warningIsPre ? "Vorabinformation: " : "Achtung: ") + Self.calm(warning) + ".")
        }
        return parts.joined(separator: " ") + offlineNote(s.stand, offline: s.offline)
    }

    /// "Amtliche WARNUNG vor STURMBÖEN" -> "Amtliche Warnung vor Sturmböen" (no shouting in speech).
    static func calm(_ text: String) -> String { CalmText.calm(text) }

    // MARK: environment

    /// "Luftqualität gut an der UBA-Station Bielefeld-Ost, 21:00 Uhr. Pollen: heute keine Belastung. UV-Index heute 0, niedrig. …"
    static func environment(_ e: EnvironmentResponse, stand: Date, offline: Bool) -> String {
        var parts: [String] = []
        if let air = e.luft, let text = air.text {
            var sentence = "Luftqualität \(text)"
            if let station = air.station { sentence += " an der UBA-Station \(station)" }
            if let t = Fmt.parse(air.stand) { sentence += ", \(Fmt.time(t)) Uhr" }
            parts.append(sentence + ".")
        }
        if let types = e.pollen?.arten, !types.isEmpty {
            let today = types
                .filter { ($0.heute?.wert ?? 0) > 0 }
                .sorted { ($0.heute?.wert ?? 0) > ($1.heute?.wert ?? 0) }
                .map { "\($0.name ?? $0.id) \($0.heute?.text ?? "")" }
            parts.append(today.isEmpty ? "Pollen: heute keine Belastung." : "Pollen heute: " + today.joined(separator: ", ") + ".")
        }
        if let day = e.uv?.heute, let index = day.uvIndex {
            parts.append("UV-Index heute \(Fmt.number(index, decimals: 0))" + (day.stufe.map { ", \($0)" } ?? "") + ".")
        }
        if let sun = e.astro?.sonne, let rise = Fmt.parse(sun.aufgang), let set = Fmt.parse(sun.untergang) {
            parts.append("Sonne von \(Fmt.time(rise)) bis \(Fmt.time(set)) Uhr.")
        }
        if let moon = e.astro?.mond, let pct = moon.beleuchtungPct {
            parts.append("Mond: \(moon.phase ?? "Mond"), \(Int(pct.rounded())) Prozent beleuchtet.")
        }
        guard !parts.isEmpty else { return "Der Wetterserver hat gerade keine Umweltdaten." }
        return parts.joined(separator: " ") + offlineNote(stand, offline: offline)
    }

    // MARK: loading (Siri, Shortcuts and the app's Siri screen)

    static func loadGarden() async -> String {
        let api = APIClient()
        async let nowCall: Fetched<WeatherNow> = api.fetch(.now, timeout: 8)
        async let historyCall: Fetched<HistoryResponse> = api.fetch(HistoryUnit.monate.endpoint, timeout: 8)
        guard let now = try? await nowCall else { return noServer }
        let today = (try? await historyCall).flatMap { HistoryWidgetData($0.value, stand: $0.date, offline: $0.fromCache) }
        return garden(now: now.value, today: today, stand: now.date, offline: now.fromCache)
    }

    static func loadRain() async -> String {
        guard let result: Fetched<NowcastResponse> = try? await APIClient().fetch(.nowcast, timeout: 8) else { return noServer }
        return rain(result.value, stand: result.date, offline: result.fromCache)
    }

    static func loadWarnings() async -> String {
        guard let result: Fetched<AlertsResponse> = try? await APIClient().fetch(.alerts, timeout: 8) else { return noServer }
        let reference = APIClient.isMock ? (Fmt.parse(result.value.generatedAt) ?? Date()) : Date()
        return warnings(result.value, reference: reference, stand: result.date, offline: result.fromCache)
    }

    static func loadEnvironment() async -> String {
        do {
            let result: Fetched<EnvironmentResponse> = try await APIClient().fetch(.environment, timeout: 8)
            return environment(result.value, stand: result.date, offline: result.fromCache)
        } catch {
            // an older server answers 404: say so instead of "not reachable"
            return (error as? LocalizedError)?.errorDescription ?? noServer
        }
    }

    static func loadWeather() async -> String {
        guard let snapshot = await WidgetSnapshot.load() else { return noServer }
        return weather(snapshot)
    }
}
