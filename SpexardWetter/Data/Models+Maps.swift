import Foundation

// MARK: - /api/v1/karten

/// Own maps of the server from DWD ICON-D2 (2.2 km) for NRW: one processed run, a fixed map box
/// (Web-Mercator PNGs of `map.width` x `map.height` pixels) and per layer its legend and frames.
/// The image of a frame: `bild` with `lauf` = `run.id`, `layer` = layer id, `zeit` = `frames[].zeit`.
struct MapsResponse: Decodable {
    struct Location: Decodable {
        let label: String?
        @Lenient var lat: Double?
        @Lenient var lon: Double?
    }

    struct Run: Decodable {
        /// "2026110615" (YYYYMMDDHH, UTC).
        let id: String
        let model: String?
        @Lenient var resolutionKm: Double?
        /// Start of the run (local time and UTC).
        let init_: String?
        let initUtc: String?
        /// "ICON-D2 Lauf 15 UTC".
        let label: String?
        /// When the server rendered the run.
        let processed: String?
        let stale: Bool?

        enum CodingKeys: String, CodingKey {
            case id, model, resolutionKm, initUtc, label, processed, stale
            case init_ = "init"
        }
    }

    struct MapInfo: Decodable {
        let bounds: RadarResponse.Bounds
        let width: Int?
        let height: Int?
        let projection: String?
    }

    struct LegendClass: Decodable, Identifiable {
        /// Lower bound (inclusive) of the class.
        let from: Double
        /// Upper bound (exclusive); nil for the top class.
        @Lenient var to: Double?
        /// "#rrggbb".
        let color: String

        var id: Double { from }
    }

    struct Legend: Decodable {
        let unit: String?
        let classes: [LegendClass]
        let ticks: [Double]?
        /// "transparent": values below the first class are not drawn; "clamp": they get its colour.
        let below: String?
        let decimals: Int?
    }

    struct Frame: Decodable, Identifiable {
        /// Valid time in UTC ("2026-11-06T18:00Z"), the `zeit` of the image.
        let zeit: String
        /// Valid time in local time.
        let time: String
        /// Hours after the run start.
        let stunde: Int
        /// Largest value in the map box (nil: nothing drawn).
        @Lenient var max: Double?
        /// Value at the rounded location (nil: no value, e.g. no echo).
        @Lenient var standort: Double?
        /// [lat, lon] (0.1°) of the largest value; nil when it has no single place.
        @Lenient var maxBei: [Double]?
        /// "im Oberharz", "bei Siegen", "verbreitet".
        let maxOrt: String?
        /// Smallest value with place (temperature and freezing level only).
        @Lenient var min: Double?
        @Lenient var minBei: [Double]?
        let minOrt: String?

        var id: String { zeit }
    }

    struct Layer: Decodable, Identifiable {
        let id: String
        let title: String
        let short: String?
        let unit: String?
        /// Layers of one group (the precipitation sums) are offered as one choice with variants.
        let group: String?
        let description: String?
        let note: String?
        /// What the time of a frame means ("Stunde davor", "seit Laufbeginn").
        let period: String?
        /// One plain sentence about the whole run, only from the frame values.
        let satz: String?
        /// Glossary entries of the layer (`/api/v1/glossar` ids), the first one is the main term.
        let glossar: [String]?
        let legend: Legend
        let frames: [Frame]
    }

    let generatedAt: String?
    let location: Location?
    let run: Run?
    let map: MapInfo?
    let bild: String?
    let layers: [Layer]
    let sourceErrors: [SourceProblem]?
    let attribution: [String]?
}

extension MapsResponse {
    /// Path of a frame's PNG, from the server's template (`bild`).
    func imagePath(layer: String, frame: Frame) -> String? {
        guard let run else { return nil }
        let template = bild ?? "/api/v1/karten/bild?lauf={lauf}&layer={layer}&zeit={zeit}"
        func q(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s }
        return template
            .replacingOccurrences(of: "{lauf}", with: q(run.id))
            .replacingOccurrences(of: "{layer}", with: q(layer))
            .replacingOccurrences(of: "{zeit}", with: q(frame.zeit))
    }
}

/// One choice of the layer picker: a layer, or a group of layers (the precipitation sums) with variants.
struct MapChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let layerIds: [String]

    /// Choices in the server's order; layers of one group form a single choice.
    static func choices(_ layers: [MapsResponse.Layer]) -> [MapChoice] {
        var out: [MapChoice] = []
        for layer in layers {
            if let group = layer.group, !group.isEmpty {
                if let i = out.firstIndex(where: { $0.id == "group:" + group }) {
                    out[i] = MapChoice(id: out[i].id, title: out[i].title, layerIds: out[i].layerIds + [layer.id])
                } else {
                    out.append(MapChoice(id: "group:" + group, title: MapWords.groupTitle(group), layerIds: [layer.id]))
                }
            } else {
                out.append(MapChoice(id: layer.id, title: layer.short ?? layer.title, layerIds: [layer.id]))
            }
        }
        return out
    }
}

/// Wording of the maps (values with the legend's unit and decimals, run and valid time).
enum MapWords {
    static func groupTitle(_ group: String) -> String {
        switch group {
        case "niederschlag": return "Niederschlag"
        default: return group.prefix(1).uppercased() + group.dropFirst()
        }
    }

    /// "Regen 1 h" -> "1 h" inside the precipitation group (the variant names).
    static func variantTitle(_ layer: MapsResponse.Layer) -> String {
        switch layer.id {
        case "niederschlag_1h": return "1 Stunde"
        case "niederschlag_3h": return "3 Stunden"
        case "niederschlag_summe": return "seit Laufbeginn"
        default: return layer.short ?? layer.title
        }
    }

    /// "7,3 °C", "12 km/h", "0,4 mm" with the decimals of the legend.
    static func value(_ v: Double?, _ layer: MapsResponse.Layer) -> String? {
        guard let v, v.isFinite else { return nil }
        let unit = layer.legend.unit ?? layer.unit ?? ""
        let text = Fmt.number(v, decimals: layer.legend.decimals ?? 0)
        return unit.isEmpty ? text : "\(text) \(unit)"
    }

    /// Lower bound of the first drawn class ("unter 0,1 mm" means nothing is drawn).
    static func threshold(_ layer: MapsResponse.Layer) -> String? {
        guard layer.legend.below == "transparent", let first = layer.legend.classes.first else { return nil }
        return value(first.from, layer)
    }

    /// "2–5 mm", "ab 100 mm" of a legend class.
    static func range(_ c: MapsResponse.LegendClass, _ layer: MapsResponse.Layer) -> String {
        let unit = layer.legend.unit ?? layer.unit ?? ""
        func n(_ v: Double) -> String { Fmt.number(v, decimals: v.rounded() == v ? 0 : 1) }
        guard let to = c.to else { return "ab \(n(c.from)) \(unit)" }
        return "\(n(c.from))–\(n(to)) \(unit)"
    }

    /// "ICON-D2 Lauf 15 UTC" (the server's label, else from the run id).
    static func runLabel(_ run: MapsResponse.Run) -> String {
        if let label = run.label, !label.isEmpty { return label }
        let hour = run.id.suffix(2)
        if let date = Fmt.parse(run.init_) {
            return "ICON-D2 Lauf \(Fmt.weekdayShort(date)) \(hour) UTC"
        }
        return "ICON-D2 Lauf \(hour) UTC"
    }

    /// "Sa 06:00" of a frame.
    static func validLabel(_ frame: MapsResponse.Frame) -> String {
        guard let date = Fmt.parse(frame.time) else { return "–" }
        return "\(Fmt.weekdayShort(date)) \(Fmt.time(date))"
    }
}
