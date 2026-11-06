import Foundation

// MARK: - /api/v1/radar/bilder and /api/v1/radar/umkreis

/// DWD radar (RV: analysis + 2-hour nowcast, 1-km pixels, 5-minute steps) around the location.
/// `frames[].rle` = rain-rate class per pixel as runs `[class, count, ...]`, row by row from the
/// north-west corner, on a square Web-Mercator raster with the outer edges `map.bounds`.
struct RadarResponse: Decodable {
    struct Location: Decodable {
        let label: String?
        @Lenient var lat: Double?
        @Lenient var lon: Double?
    }

    struct Bounds: Decodable {
        let south: Double
        let west: Double
        let north: Double
        let east: Double
    }

    struct MapInfo: Decodable {
        let bounds: Bounds
        /// Pixels per side of the square raster.
        let size: Int
        @Lenient var radiusKm: Double?
        let projection: String?
    }

    struct RadarClass: Decodable, Identifiable {
        let `class`: Int
        let fromMmH: Double
        /// Upper bound (exclusive); nil for the top class.
        @Lenient var toMmH: Double?
        /// WMO word: "leicht", "mäßig", "stark", "sehr stark".
        let intensity: String?

        var id: Int { `class` }
    }

    /// Statistics of one frame within `map.radius_km` around the location.
    struct Stats: Decodable {
        let time: String?
        @Lenient var wetPct: Double?
        @Lenient var nearestKm: Double?
        let nearestDir: String?
        @Lenient var maxMmH: Double?
        @Lenient var maxKm: Double?
        let maxDir: String?
        let scattered: Bool?
    }

    struct Frame: Decodable {
        /// End of the 5-minute interval.
        let time: String
        /// "radar" (measured) or "prognose" (DWD nowcast).
        let kind: String?
        @Lenient var wetPct: Double?
        @Lenient var nearestKm: Double?
        let nearestDir: String?
        @Lenient var maxMmH: Double?
        @Lenient var maxKm: Double?
        let maxDir: String?
        let scattered: Bool?
        let rle: [Int]?

        var isForecast: Bool { kind == "prognose" }
    }

    struct Umkreis: Decodable {
        let analysis: String?
        let now: Stats?
        let in60Min: Stats?
        /// näher | weiter | gleich | abgezogen | neu
        let trend: String?
        let nowcastUntil: String?
        let text: String?
    }

    let generatedAt: String?
    let location: Location?
    let map: MapInfo
    let classes: [RadarClass]
    let analysis: String?
    let frames: [Frame]
    let umkreis: Umkreis?
    let sourceErrors: [SourceProblem]?

    /// Index of the newest measured frame (the analysis), else the last radar frame, else 0.
    var latestRadarIndex: Int {
        if let analysis, let exact = frames.firstIndex(where: { $0.time == analysis }) { return exact }
        return frames.lastIndex(where: { !$0.isForecast }) ?? 0
    }
}

/// Wording of the radar statistics (same words as the website).
enum RadarWords {
    private static let directions: [String: String] = [
        "N": "nördlich", "NO": "nordöstlich", "O": "östlich", "SO": "südöstlich",
        "S": "südlich", "SW": "südwestlich", "W": "westlich", "NW": "nordwestlich",
    ]

    /// "23 km westlich", "am Standort" (no direction), "–" without precipitation.
    static func whereText(_ km: Double?, _ dir: String?) -> String {
        guard let km else { return "–" }
        guard let dir, !dir.isEmpty else { return "am Standort" }
        return "\(Int(km.rounded())) km \(directions[dir] ?? dir)"
    }

    /// "W" -> "westlich".
    static func directionWord(_ dir: String) -> String { directions[dir] ?? dir }

    static func trend(_ value: String?) -> String? {
        switch value {
        case "näher": return "kommt näher"
        case "weiter": return "entfernt sich"
        case "gleich": return "bleibt etwa gleich weit entfernt"
        case "abgezogen": return "in einer Stunde nicht mehr im Umkreis"
        case "neu": return "erreicht den Umkreis"
        default: return nil
        }
    }

    /// "0,1–0,5", "ab 50" (mm/h without unit).
    static func range(_ c: RadarResponse.RadarClass) -> String {
        func n(_ v: Double) -> String { Fmt.number(v, decimals: v < 1 || v.rounded() != v ? 1 : 0) }
        guard let to = c.toMmH else { return "ab \(n(c.fromMmH))" }
        return "\(n(c.fromMmH))–\(n(to))"
    }

    static func share(_ pct: Double?) -> String {
        guard let pct else { return "–" }
        if pct > 0 && pct < 0.1 { return "unter 0,1 %" }
        return Fmt.number(pct, decimals: pct >= 10 ? 0 : 1) + " %"
    }

    /// "Radar 17:35" / "Prognose 18:20" and "−35 min" / "+45 min" / "jüngstes Radarbild".
    static func frameLabel(_ frame: RadarResponse.Frame?, analysis: String?) -> (kind: String, time: String, offset: String) {
        guard let frame, let t = Fmt.parse(frame.time) else { return ("Radar", "–", "") }
        var offset = ""
        if let a = Fmt.parse(analysis) {
            let minutes = Int((t.timeIntervalSince(a) / 60).rounded())
            if minutes == 0 {
                offset = "jüngstes Radarbild"
            } else {
                offset = (minutes > 0 ? "+" : "\u{2212}") + "\(abs(minutes)) min"
            }
        }
        return (frame.isForecast ? "Prognose" : "Radar", Fmt.time(t), offset)
    }
}
