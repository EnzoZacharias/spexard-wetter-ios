import Foundation
import SwiftUI

// MARK: - /api/v1/orte/suche, /api/v1/ort

/// A place in Germany from the server's search (Open-Meteo geocoding, coordinates rounded to two
/// decimals by the server). Stored on the device only.
struct Place: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let region: String?
    let lat: Double
    let lon: Double
    let hoeheM: Double?

    /// "lat=52.09&lon=8.74" (two decimals, point; exactly what the search gave).
    var query: String { String(format: "lat=%.2f&lon=%.2f", lat, lon) }

    var forecastEndpoint: Endpoint { Endpoint(path: "/api/v1/ort?\(query)", mock: "mock_ort") }
}

struct PlaceSearchResponse: Decodable {
    let treffer: [Place]?
    let quelle: String?
}

extension Endpoint {
    static func placeSearch(_ text: String) -> Endpoint {
        let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?"))) ?? text
        return Endpoint(path: "/api/v1/orte/suche?q=\(q)", mock: "mock_orte_suche")
    }
}

/// The lean forecast for another place: model value of the current hour, 48 hours, 16 days and the
/// DWD warnings of its municipality (no measurements, no professional pages).
struct PlaceForecastResponse: Decodable {
    struct Info: Decodable {
        @Lenient var lat: Double?
        @Lenient var lon: Double?
        /// Model height of Open-Meteo.
        @Lenient var hoeheM: Double?
        /// Name of the DWD warn cell's place, nil when unknown.
        let name: String?
        let kreis: String?
        let land: String?
        let warnzelle: String?
        let heimat: Bool?
    }

    struct Now: Decodable {
        let zeit: String?
        @Lenient var temperaturC: Double?
        @Lenient var niederschlagMm: Double?
        @Lenient var regenWahrscheinlichkeitPct: Double?
        @Lenient var wetterCode: Int?
        let wetter: String?
        @Lenient var windKmh: Double?
        @Lenient var boeenKmh: Double?
        @Lenient var windRichtungGrad: Double?
        @Lenient var istTag: Bool?
    }

    /// 48 hours from the current one, index-aligned with `zeit`.
    struct Hours: Decodable {
        let zeit: [String]
        let temperaturC: [Double?]?
        let niederschlagMm: [Double?]?
        let regenWahrscheinlichkeitPct: [Double?]?
        let wetterCode: [Int?]?
        let windKmh: [Double?]?
        let boeenKmh: [Double?]?
        let windRichtungGrad: [Double?]?
        /// 1 = day, 0 = night.
        let istTag: [Int?]?
    }

    struct Day: Decodable, Identifiable {
        let datum: String
        @Lenient var wetterCode: Int?
        let wetter: String?
        @Lenient var maxC: Double?
        @Lenient var minC: Double?
        @Lenient var niederschlagMm: Double?
        @Lenient var regenWahrscheinlichkeitPct: Double?
        @Lenient var windMaxKmh: Double?
        @Lenient var boeenMaxKmh: Double?
        @Lenient var windRichtungGrad: Double?
        let sonnenaufgang: String?
        let sonnenuntergang: String?

        var id: String { datum }
    }

    let generatedAt: String?
    let ort: Info?
    let jetzt: Now?
    let stunden: Hours?
    let tage: [Day]?
    /// nil = not available, [] = none.
    let warnungen: [DwdWarning]?
    let sourceErrors: [SourceProblem]?

    /// The hours as items of the hourly strip.
    func hourItems() -> [HourItem] {
        guard let h = stunden else { return [] }
        func at<T>(_ list: [T?]?, _ i: Int) -> T? {
            guard let list, list.indices.contains(i) else { return nil }
            return list[i]
        }
        return h.zeit.indices.compactMap { i -> HourItem? in
            guard let date = Fmt.parse(h.zeit[i]) else { return nil }
            let day = at(h.istTag, i).map { $0 == 1 } ?? true
            return HourItem(
                id: date,
                label: Fmt.hour(date) + " Uhr",
                symbol: WeatherSymbol.name(code: at(h.wetterCode, i), night: !day),
                temp: at(h.temperaturC, i),
                rainProb: at(h.regenWahrscheinlichkeitPct, i),
                precip: at(h.niederschlagMm, i),
                wind: at(h.windKmh, i),
                windDir: at(h.windRichtungGrad, i),
                gust: at(h.boeenKmh, i)
            )
        }
    }

    /// Sunrises and sunsets inside the hours.
    func sunEvents() -> [SunEvent] {
        let dates = (stunden?.zeit ?? []).compactMap { Fmt.parse($0) }
        guard let first = dates.first, let last = dates.last else { return [] }
        var out: [SunEvent] = []
        for day in tage ?? [] {
            if let rise = Fmt.parse(day.sonnenaufgang), rise > first, rise < last { out.append(SunEvent(id: rise, rise: true)) }
            if let set = Fmt.parse(day.sonnenuntergang), set > first, set < last { out.append(SunEvent(id: set, rise: false)) }
        }
        return out
    }

    func dayItems(reference: Date) -> [DayItem] {
        (tage ?? []).compactMap { d in
            guard let date = Fmt.parse(d.datum) else { return nil }
            return DayItem(
                id: d.datum,
                date: date,
                label: Fmt.weekday(date, reference: reference),
                dateLabel: Fmt.dayMonth(date),
                symbol: WeatherSymbol.name(code: d.wetterCode, night: false),
                tmin: d.minC,
                tmax: d.maxC,
                rainProb: d.regenWahrscheinlichkeitPct,
                confidence: nil
            )
        }
    }
}

/// The favourite places and the chosen one, only on this device (UserDefaults). nil = home.
@MainActor
final class PlaceStore: ObservableObject {
    static let shared = PlaceStore()

    @Published private(set) var favorites: [Place] = []
    @Published private(set) var selected: Place?

    private let favoritesKey = "orteFavoriten"
    private let selectedKey = "orteAuswahl"

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: favoritesKey), let list = try? JSONDecoder().decode([Place].self, from: data) {
            favorites = list
        }
        if let data = defaults.data(forKey: selectedKey), let place = try? JSONDecoder().decode(Place.self, from: data) {
            selected = place
        }
        // screenshots: `-mock -place` shows the example place
        if APIClient.isMock {
            favorites = []
            selected = nil
            if ProcessInfo.processInfo.arguments.contains("-place"), let place = Self.mockPlace {
                favorites = [place]
                selected = place
            }
        }
    }

    /// The first hit of the bundled example search.
    static var mockPlace: Place? {
        guard let url = Bundle.main.url(forResource: "mock_orte_suche", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let answer = try? APIClient.decode(data, as: PlaceSearchResponse.self) else { return nil }
        return answer.treffer?.first
    }

    func isFavorite(_ place: Place) -> Bool { favorites.contains { $0.id == place.id } }

    /// Show this place (nil = home); a chosen place goes into the favourites.
    func select(_ place: Place?) {
        selected = place
        if let place, !isFavorite(place) { favorites.append(place) }
        save()
    }

    func toggleFavorite(_ place: Place) {
        if isFavorite(place) {
            favorites.removeAll { $0.id == place.id }
        } else {
            favorites.append(place)
        }
        save()
    }

    func remove(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        guard !APIClient.isMock else { return }
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(favorites), forKey: favoritesKey)
        if let selected {
            defaults.set(try? JSONEncoder().encode(selected), forKey: selectedKey)
        } else {
            defaults.removeObject(forKey: selectedKey)
        }
    }
}
