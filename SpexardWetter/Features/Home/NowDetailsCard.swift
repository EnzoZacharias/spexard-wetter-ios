import SwiftUI

/// Current details from `weather_now`: the measured value where a DWD station has one, else the
/// model (marked), plus today's sunrise and sunset.
struct NowDetailsCard: View {
    let now: WeatherNow?
    let sun: HoursResponse.Sun?

    private struct Tile: Identifiable {
        let id: String
        let icon: String
        let title: String
        let value: String
        let note: String?
        /// Glossary entry behind the value (info button).
        var info: String?
    }

    /// Notes of the server shown under the tiles when one of these values is conspicuous now.
    static let noteIds = ["boee", "taupunkt", "spread", "nebel", "drucktendenz", "frost"]

    private var tiles: [Tile] {
        guard let n = now?.now else { return [] }
        var out: [Tile] = []
        func source(_ pair: WeatherNow.Pair?) -> String? {
            guard let best = pair?.best else { return nil }
            return best.measured ? pair?.station.map { "DWD \($0)" } : "Modell"
        }
        if let wind = n.windSpeedKmh?.best {
            let dir = n.windDirectionDeg?.best.map { " aus " + Fmt.compass($0.value) } ?? ""
            var note = source(n.windSpeedKmh)
            if let gust = n.windGustsKmh?.measuredMax60min ?? n.windGustsKmh?.best?.value {
                note = "Böen \(Fmt.wind(gust))" + (note.map { " · \($0)" } ?? "")
            }
            out.append(Tile(id: "wind", icon: "wind", title: "Wind", value: Fmt.wind(wind.value) + dir, note: note, info: "beaufort"))
        }
        if let h = n.humidityPct?.best {
            out.append(Tile(id: "rh", icon: "humidity.fill", title: "Luftfeuchte", value: Fmt.percent(h.value), note: source(n.humidityPct)))
        }
        if let d = n.dewPointC?.best {
            out.append(Tile(id: "dew", icon: "drop.fill", title: "Taupunkt", value: Fmt.temp(d.value, decimals: 1), note: source(n.dewPointC), info: "taupunkt"))
        }
        if let p = n.pressureMslHpa?.best {
            out.append(Tile(id: "p", icon: "gauge.with.dots.needle.50percent", title: "Luftdruck", value: Fmt.value(p.value, 0, "hPa"), note: source(n.pressureMslHpa), info: "luftdruck"))
        }
        if let c = n.cloudCoverPct?.best {
            out.append(Tile(id: "cloud", icon: "cloud.fill", title: "Bewölkung", value: Fmt.percent(c.value), note: source(n.cloudCoverPct)))
        }
        if let v = n.visibilityM?.best {
            let text = v.value >= 1000 ? Fmt.value(v.value / 1000, v.value >= 10_000 ? 0 : 1, "km") : Fmt.value(v.value, 0, "m")
            out.append(Tile(id: "vis", icon: "eye.fill", title: "Sicht", value: text, note: source(n.visibilityM)))
        }
        if let rain = n.precipitationMm {
            if let hour = rain.measured60min {
                out.append(Tile(id: "rain", icon: "cloud.rain.fill", title: "Regen letzte Stunde", value: Fmt.precip(hour), note: rain.station.map { "DWD \($0)" }))
            } else if let model = rain.model15min {
                out.append(Tile(id: "rain", icon: "cloud.rain.fill", title: "Regen 15 min", value: Fmt.precip(model), note: "Modell"))
            }
        }
        if let sun, sun.sunrise != nil || sun.sunset != nil {
            out.append(Tile(id: "sun", icon: "sunrise.fill", title: "Sonne", value: "\(sun.sunrise ?? "–") – \(sun.sunset ?? "–")", note: "Auf- und Untergang"))
        }
        return out
    }

    var body: some View {
        let items = tiles
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                CardTitle("Jetzt im Detail", systemImage: "list.bullet.rectangle")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(items) { tile in
                        HStack(alignment: .top, spacing: 2) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: tile.icon)
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.callout)
                                    .frame(width: 22)
                                    .opacity(0.9)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tile.title).font(.caption2).opacity(0.75)
                                    Text(tile.value).font(.callout.weight(.semibold))
                                    if let note = tile.note {
                                        Text(note).font(.caption2).opacity(0.65).lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                            Spacer(minLength: 0)
                            if let info = tile.info { InfoButton(info, compact: true) }
                        }
                    }
                }
                GlossaryNotesView(Self.noteIds)
            }
            .card()
        }
    }
}
