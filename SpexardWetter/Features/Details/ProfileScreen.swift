import Charts
import SwiftUI

extension Endpoint {
    static let sounding = Endpoint(path: "/api/v1/profil/sonde", mock: "mock_profil_sonde")
}

/// The latest radiosonde ascent: temperature and dew point over height, indices, inversions.
struct ProfileScreen: View {
    @StateObject private var loader = Loader<SoundingResponse>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    SoundingContent(data: data)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Quellen: DWD (TEMP), University of Wyoming, Open-Meteo.com (CC BY 4.0)")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.reload()
        }
        .task { await loader.loadIfNeeded(.sounding, maxAge: 1800) }
        .screenBackground()
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SoundingContent: View {
    let data: SoundingResponse

    private struct ProfilePoint: Identifiable {
        let id: Int
        let height: Double
        let value: Double
    }

    /// Height above sea level (m) of every level with a value.
    private func profile(_ value: (SoundingResponse.Level) -> Double?) -> [ProfilePoint] {
        (data.ebenen ?? []).enumerated().compactMap { i, level in
            guard let z = level.zMslM ?? level.zM, let v = value(level) else { return nil }
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
                    Text("Gelbe Bänder: Inversionen (es wird mit der Höhe wärmer). Höhe über dem Meer.")
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
                Fact(label: "Nullgradgrenze", value: Fmt.value(data.nullgradMslM, 0, "m"))
                Fact(label: "Feuchtkugel-Null", value: Fmt.value(data.feuchtkugelNullMslM, 0, "m"))
                Fact(label: "Niederschlagswasser", value: Fmt.value(data.indizes?.niederschlagswasserMm, 1, "mm"))
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
