import Foundation

/// SF Symbols for the server's weather: WMO codes (hourly `symbol`) and German weather texts
/// (`now.weather`, daily model `weather`). Multicolor variants, like the big weather apps.
enum WeatherSymbol {
    /// WMO weather code (0 clear ... 99 thunderstorm with hail).
    static func name(code: Int?, night: Bool) -> String {
        guard let code else { return "questionmark.circle" }
        switch code {
        case 0: return night ? "moon.stars.fill" : "sun.max.fill"
        case 1, 2: return night ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61, 63, 66: return "cloud.rain.fill"
        case 65, 67: return "cloud.heavyrain.fill"
        case 71...77: return "cloud.snow.fill"
        case 80, 81: return night ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill"
        case 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// German weather text ("leichte Schneeschauer", "teils bewölkt", "trocken, bedeckt").
    static func name(text: String?, night: Bool) -> String {
        guard let text = text?.lowercased(), !text.isEmpty else { return "questionmark.circle" }
        if text.contains("gewitter") { return "cloud.bolt.rain.fill" }
        if text.contains("schnee") || text.contains("graupel") { return "cloud.snow.fill" }
        if text.contains("schauer") { return night ? "cloud.moon.rain.fill" : "cloud.sun.rain.fill" }
        if text.contains("starker regen") || text.contains("kräftiger regen") { return "cloud.heavyrain.fill" }
        if text.contains("regen") { return "cloud.rain.fill" }
        if text.contains("niesel") || text.contains("sprüh") { return "cloud.drizzle.fill" }
        if text.contains("nebel") || text.contains("dunst") { return "cloud.fog.fill" }
        if text.contains("bedeckt") || text.contains("stark bewölkt") { return "cloud.fill" }
        if text.contains("bewölkt") || text.contains("wolkig") || text.contains("überwiegend klar") {
            return night ? "cloud.moon.fill" : "cloud.sun.fill"
        }
        if text.contains("klar") || text.contains("sonnig") || text.contains("heiter") {
            return night ? "moon.stars.fill" : "sun.max.fill"
        }
        return "cloud.fill"
    }
}
