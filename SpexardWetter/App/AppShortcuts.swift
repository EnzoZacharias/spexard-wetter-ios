import AppIntents

// Siri and the Shortcuts app ("Hey Siri, Spexard Wetter Garten"). The intents ask the weather
// server without opening the app and answer with the sentences of `SiriAnswers`.

struct GardenTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "Temperatur im Garten"
    static var description = IntentDescription("Sagt die Temperatur des Gartensensors und den Tiefst- und Höchstwert von heute.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = await SiriAnswers.loadGarden()
        return .result(value: text, dialog: "\(text)")
    }
}

struct RainSoonIntent: AppIntent {
    static var title: LocalizedStringResource = "Regen in 2 Stunden"
    static var description = IntentDescription("Sagt, ob in den nächsten zwei Stunden Regen kommt (Radar-Nowcast des DWD am Standort).")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = await SiriAnswers.loadRain()
        return .result(value: text, dialog: "\(text)")
    }
}

struct WeatherWarningsIntent: AppIntent {
    static var title: LocalizedStringResource = "Amtliche Warnungen"
    static var description = IntentDescription("Sagt, ob der DWD für den Ort gerade warnt, und bis wann.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = await SiriAnswers.loadWarnings()
        return .result(value: text, dialog: "\(text)")
    }
}

struct WeatherNowIntent: AppIntent {
    static var title: LocalizedStringResource = "Wetter jetzt"
    static var description = IntentDescription("Temperatur, Himmel, Spanne von heute, Regen in den nächsten zwei Stunden und eine Warnung, falls es eine gibt.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = await SiriAnswers.loadWeather()
        return .result(value: text, dialog: "\(text)")
    }
}

/// The phrases Siri knows without any setup. Every phrase names the app (Apple's rule); the app
/// shows them under Mehr → Siri & Kurzbefehle (`SiriScreen`, keep both lists the same).
struct SpexardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GardenTemperatureIntent(),
            phrases: [
                "Wie warm ist es im Garten bei \(.applicationName)",
                "\(.applicationName) Garten",
                "Temperatur im Garten mit \(.applicationName)",
            ],
            shortTitle: "Garten",
            systemImageName: "thermometer.medium"
        )
        AppShortcut(
            intent: RainSoonIntent(),
            phrases: [
                "Regnet es gleich bei \(.applicationName)",
                "\(.applicationName) Regen",
                "Kommt Regen laut \(.applicationName)",
            ],
            shortTitle: "Regen gleich?",
            systemImageName: "cloud.rain"
        )
        AppShortcut(
            intent: WeatherWarningsIntent(),
            phrases: [
                "Gibt es eine Wetterwarnung bei \(.applicationName)",
                "\(.applicationName) Warnungen",
            ],
            shortTitle: "Warnungen",
            systemImageName: "exclamationmark.triangle"
        )
        AppShortcut(
            intent: WeatherNowIntent(),
            phrases: [
                "Wie ist das Wetter bei \(.applicationName)",
                "Wetter jetzt bei \(.applicationName)",
            ],
            shortTitle: "Wetter jetzt",
            systemImageName: "cloud.sun"
        )
    }
}
