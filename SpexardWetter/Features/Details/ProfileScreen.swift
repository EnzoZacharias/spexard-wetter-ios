import Charts
import SwiftUI

extension Endpoint {
    static let sounding = Endpoint(path: "/api/v1/profil/sonde", mock: "mock_profil_sonde")
}

enum ProfileView: String, CaseIterable, Identifiable {
    case sonde, icon_d2, ecmwf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sonde: return "Sonde"
        case .icon_d2: return "ICON-D2"
        case .ecmwf: return "ECMWF"
        }
    }
}

/// The latest radiosonde ascent and the time-height cross-sections of ICON-D2 and ECMWF.
struct ProfileScreen: View {
    @StateObject private var sounding = Loader<SoundingResponse>()
    @StateObject private var section = Loader<CrossSectionResponse>()
    @State private var view: ProfileView = LaunchArgs.option.flatMap(ProfileView.init(rawValue:)) ?? .sonde

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Ansicht", selection: $view) {
                    ForEach(ProfileView.allCases) { v in
                        Text(v.label).tag(v)
                    }
                }
                .pickerStyle(.segmented)

                if view == .sonde {
                    if sounding.fromCache { OfflineBanner(date: sounding.date) }
                    if let data = sounding.value {
                        SoundingContent(data: data)
                    } else if let error = sounding.error {
                        StateMessage(kind: .error, text: error) { await sounding.reload() }.card()
                    } else {
                        StateMessage(kind: .loading).card()
                    }
                    StandFooter(date: sounding.date, fromCache: sounding.fromCache, sources: "Quellen: DWD (TEMP), University of Wyoming, Open-Meteo.com (CC BY 4.0)")
                } else {
                    if section.fromCache { OfflineBanner(date: section.date) }
                    if let data = section.value {
                        CrossSectionCard(data: data)
                            .opacity(section.loading ? 0.6 : 1)
                    } else if let error = section.error {
                        StateMessage(kind: .error, text: error) { await section.reload() }.card()
                    } else {
                        StateMessage(kind: .loading).card()
                    }
                    StandFooter(date: section.date, fromCache: section.fromCache, sources: "Wetterdaten: Open-Meteo.com (CC BY 4.0)")
                }
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await load(force: true)
        }
        .task(id: view) { await load(force: false) }
        .screenBackground()
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func load(force: Bool) async {
        if view == .sonde {
            if force { await sounding.load(.sounding) } else { await sounding.loadIfNeeded(.sounding, maxAge: 1800) }
        } else {
            let e = Endpoint(path: "/api/v1/profil/schnitt?modell=\(view.rawValue)", mock: "mock_profil_schnitt_\(view.rawValue)")
            if force { await section.load(e) } else { await section.loadIfNeeded(e, maxAge: 1800) }
        }
    }
}

struct SoundingContent: View {
    let data: SoundingResponse

    private struct ProfilePoint: Identifiable {
        let id: Int
        let height: Double
        let value: Double
    }

    /// Height above the station (m) of every level with a value (the inversions use the same base).
    private func profile(_ value: (SoundingResponse.Level) -> Double?) -> [ProfilePoint] {
        (data.ebenen ?? []).enumerated().compactMap { i, level in
            guard let z = level.zM ?? level.zMslM, let v = value(level) else { return nil }
            return ProfilePoint(id: i, height: z, value: v)
        }
        .sorted { $0.height < $1.height }
    }

    var body: some View {
        let temp = profile { $0.tC }
        let dew = profile { $0.tdC }
        let all = (temp + dew).map(\.value)
        let top = (temp + dew).map(\.height).max() ?? 5000
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Radiosonde \(data.station?.text ?? data.station?.name ?? "")").font(.headline)
                Text(launchText).font(.caption).opacity(0.8)
            }
            .card()

            if temp.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    CardTitle("Temperatur und Taupunkt über der Höhe", systemImage: "arrow.up.and.down")
                    HStack(spacing: 12) {
                        Label("Temperatur", systemImage: "line.diagonal").foregroundStyle(Palette.warm)
                        Label("Taupunkt", systemImage: "line.diagonal").foregroundStyle(Palette.cold)
                    }
                    .font(.caption2)
                    Chart {
                        RuleMark(x: .value("0 °C", 0.0))
                            .foregroundStyle(.white.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        ForEach(temp) { p in
                            LineMark(x: .value("°C", p.value), y: .value("Höhe", p.height), series: .value("Reihe", "Temperatur"))
                                .foregroundStyle(Palette.warm)
                                .lineStyle(StrokeStyle(lineWidth: 2.5))
                        }
                        ForEach(dew) { p in
                            LineMark(x: .value("°C", p.value), y: .value("Höhe", p.height), series: .value("Reihe", "Taupunkt"))
                                .foregroundStyle(Palette.cold)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                        ForEach(Array((data.inversionen ?? []).enumerated()), id: \.offset) { _, inv in
                            if let base = inv.baseM, let topM = inv.topM, let lo = all.min(), let hi = all.max() {
                                RectangleMark(
                                    xStart: .value("von", lo - 2),
                                    xEnd: .value("bis", hi + 2),
                                    yStart: .value("Basis", base),
                                    yEnd: .value("Obergrenze", topM)
                                )
                                .foregroundStyle(Palette.sun.opacity(0.15))
                            }
                        }
                    }
                    .chartXScale(domain: ((all.min() ?? -30) - 2)...((all.max() ?? 10) + 2))
                    .chartYScale(domain: 0...top)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine().foregroundStyle(.white.opacity(0.12))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(Fmt.number(v, decimals: 0) + "°").foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine().foregroundStyle(.white.opacity(0.12))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(Fmt.number(v / 1000, decimals: 1) + " km").foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }
                    }
                    .frame(height: 340)
                    .accessibilityLabel("Temperaturprofil der Radiosonde")
                    Text("Gelbe Bänder: Inversionen (es wird mit der Höhe wärmer). Höhe über der Station.")
                        .font(.caption2)
                        .opacity(0.75)
                }
                .card()
            } else {
                StateMessage(kind: .empty, text: "Keine Messwerte der Sonde").card()
            }

            factsCard
            if let cmp = data.vsIconD2 {
                VStack(alignment: .leading, spacing: 6) {
                    CardTitle("Sonde gegen ICON-D2", systemImage: "arrow.left.arrow.right")
                    if let mean = cmp.meanAbsDtK {
                        Text("Mittlere Abweichung der Temperatur: \(Fmt.number(mean, decimals: 1)) K").font(.callout)
                    }
                    if let text = cmp.assessment { Text(text).font(.footnote).opacity(0.9) }
                    if let note = cmp.note { Text(note).font(.caption2).opacity(0.7) }
                }
                .card()
            }
        }
    }

    private var launchText: String {
        var parts: [String] = []
        if let t = Fmt.parse(data.launchUtc.map(Self.utcToISO) ?? nil) {
            parts.append("Aufstieg \(Fmt.relativeDateTime(t, reference: Date()))")
        }
        if let q = data.quelle { parts.append(q) }
        return parts.joined(separator: " · ")
    }

    /// "2026-11-04T10:44Z" -> "2026-11-04T10:44+00:00" (the parser expects an offset).
    static func utcToISO(_ text: String) -> String? {
        text.hasSuffix("Z") ? String(text.dropLast()) + "+00:00" : text
    }

    private var factsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Kennwerte", systemImage: "list.bullet.rectangle")
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Nullgradgrenze", value: Fmt.value(data.nullgradMslM, 0, "m NN"))
                Fact(label: "Feuchtkugel-Null", value: Fmt.value(data.feuchtkugelNullMslM, 0, "m NN"))
                Fact(label: "Wasserdampfsäule", value: Fmt.value(data.indizes?.niederschlagswasserMm, 1, "mm"))
            }
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Lifted Index", value: Fmt.value(data.indizes?.liftedIndexK, 1, "K"))
                Fact(label: "Showalter", value: Fmt.value(data.indizes?.showalterK, 1, "K"))
                Fact(label: "K-Index", value: Fmt.value(data.indizes?.kIndex, 0))
            }
            ForEach(Array((data.pakete ?? []).enumerated()), id: \.offset) { _, p in
                Text("\(p.name ?? "Paket"): CAPE \(Fmt.value(p.capeJKg, 0, "J/kg")), CIN \(Fmt.value(p.cinJKg, 0, "J/kg")), Hebungskondensation in \(Fmt.value(p.lclM, 0, "m"))")
                    .font(.caption)
                    .opacity(0.85)
            }
            ForEach(Array((data.inversionen ?? []).enumerated()), id: \.offset) { _, inv in
                Text("\(inv.type ?? "Inversion"): \(Fmt.value(inv.baseM, 0)) bis \(Fmt.value(inv.topM, 0, "m")), \(Fmt.value(inv.strengthK, 1, "K")) wärmer")
                    .font(.caption)
                    .opacity(0.85)
            }
        }
        .card()
    }
}

/// Temperature over time and height (colour per 50-m level and hour) with the 0-°C line, the
/// boundary layer and the cloud base of a rising air parcel (LCL), all from the server.
struct CrossSectionCard: View {
    let data: CrossSectionResponse

    private struct Cell: Identifiable {
        let id: Int
        let start: Date
        let z: Double
        let half: Double
        let temp: Double
    }

    private var times: [Date?] { ChartTime.dates(data.time) }

    private var heights: [Double?] {
        let n = data.tC?.count ?? 0
        return data.zM?.expanded(n) ?? []
    }

    private var cells: [Cell] {
        let rows = data.tC ?? []
        let z = heights
        var out: [Cell] = []
        for (r, row) in rows.enumerated() {
            guard z.indices.contains(r), let height = z[r] else { continue }
            let below = r > 0 ? (z[r - 1] ?? height) : height
            let half = max((height - below) / 2, 25)
            let values = row.expanded(times.count)
            for (i, date) in times.enumerated() {
                guard let date, let t = values[i] else { continue }
                out.append(Cell(id: r * 1000 + i, start: date, z: height, half: half, temp: t))
            }
        }
        return out
    }

    /// Blue below 0 °C, white at 0 °C, orange above (fixed scale −15 … +15 °C).
    static func color(_ t: Double) -> Color {
        let x = max(-1, min(1, t / 15))
        if x < 0 {
            let k = -x
            return Color(red: 1 - 0.75 * k, green: 1 - 0.45 * k, blue: 1)
        }
        return Color(red: 1, green: 1 - 0.5 * x, blue: 1 - 0.8 * x)
    }

    var body: some View {
        let dates = times.compactMap { $0 }
        let top = heights.compactMap { $0 }.max() ?? 3000
        VStack(alignment: .leading, spacing: 8) {
            Text(data.label ?? data.modell ?? "Modell").font(.headline)
            Text("Temperatur über der Zeit und der Höhe über Grund. Farbe: blau unter 0 °C, weiß um 0 °C, orange darüber.")
                .font(.caption)
                .opacity(0.8)
            if let first = dates.first, let last = dates.last, last > first {
                let domain = first...last.addingTimeInterval(3600)
                Chart {
                    ForEach(cells) { c in
                        RectangleMark(
                            xStart: .value("Beginn", c.start),
                            xEnd: .value("Ende", c.start.addingTimeInterval(3600)),
                            yStart: .value("unten", max(0, c.z - c.half)),
                            yEnd: .value("oben", c.z + c.half)
                        )
                        .foregroundStyle(Self.color(c.temp))
                    }
                    line(data.nullgradM, label: "0-°C-Grenze", color: .white, dash: [])
                    line(data.grenzschichtM, label: "Grenzschicht", color: .black, dash: [5, 3])
                    line(data.lclM, label: "Wolkenbasis (LCL)", color: Color(red: 0.3, green: 0.3, blue: 0.3), dash: [2, 2])
                }
                .chartXScale(domain: domain)
                .chartYScale(domain: 0...top)
                .chartXAxis {
                    AxisMarks(values: ChartTime.ticks(from: domain.lowerBound, to: domain.upperBound)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(ChartTime.label(date, daily: false)).foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Fmt.number(v, decimals: 0) + " m").foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }
                .frame(height: 300)
                .accessibilityLabel("Höhenschnitt der Temperatur")
                HStack(spacing: 12) {
                    Label("0-°C-Grenze", systemImage: "line.diagonal")
                    Label("Grenzschicht", systemImage: "line.diagonal")
                    Label("Wolkenbasis", systemImage: "line.diagonal")
                }
                .font(.caption2)
                if let source = data.grenzschichtQuelle {
                    Text("Grenzschicht: \(source)").font(.caption2).opacity(0.7)
                }
            } else {
                StateMessage(kind: .empty, text: "Kein Höhenschnitt vom Modell")
            }
        }
        .card()
    }

    @ChartContentBuilder
    private func line(_ series: Series<Double>?, label: String, color: Color, dash: [CGFloat]) -> some ChartContent {
        let points = ChartSeries(label, color: color, times: times, values: series?.expanded(times.count) ?? []).points
        ForEach(points) { p in
            LineMark(x: .value("Zeit", p.date.addingTimeInterval(1800)), y: .value("Höhe", p.value), series: .value("Linie", label))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: dash))
        }
    }
}
