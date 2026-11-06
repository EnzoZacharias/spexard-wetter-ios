import SwiftUI

extension Endpoint {
    static let nowcastDetail = Endpoint(path: "/api/v1/tools/rain_nowcast?detail=full", mock: "mock_nowcast_full")
}

/// `rain_nowcast` with detail=full: the location, its ±1 km and ±3 km surroundings, the rain
/// phases and radar against the ICON-D2 model.
struct NowcastDetailResponse: Decodable {
    struct Radar: Decodable {
        let time: [String]
        let nowcastFrom: String?
        let pointMmH: Series<Double>?
        let nearMaxMmH: Series<Double>?
        let areaMaxMmH: Series<Double>?
        let areaWetPct: Series<Double>?
    }

    struct Comparison: Decodable {
        let model: String?
        let time: [String]?
        let radarMm: Series<Double>?
        let modelMm: Series<Double>?
        @Lenient var radarTotalMm: Double?
        @Lenient var modelTotalMm: Double?
    }

    struct Episode: Decodable {
        /// ISO time or words when the phase reaches beyond the window.
        let start: String?
        let end: String?
        @Lenient var mm: Double?
        @Lenient var peakMmH: Double?
        let intensity: String?
    }

    let generatedAt: String?
    let summary: NowcastResponse.Summary?
    let radar5min: Radar?
    let modelComparison15min: Comparison?
    let episodes: [Episode]?
    let sourceErrors: [SourceProblem]?
}

/// Sheet of the radar tab: what the radar says for the location in detail.
struct RadarPointSheet: View {
    @StateObject private var loader = Loader<NowcastDetailResponse>()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if loader.fromCache { OfflineBanner(date: loader.date) }
                    if let data = loader.value {
                        content(data)
                    } else if let error = loader.error {
                        StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                    } else {
                        StateMessage(kind: .loading).card()
                    }
                    StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "DWD-Radar RV via Bright Sky, ICON-D2 via Open-Meteo.com (CC BY 4.0)")
                }
                .padding(16)
            }
            .refreshable {
                Haptics.armRefresh()
                await loader.reload()
            }
            .task { await loader.loadIfNeeded(.nowcastDetail, maxAge: 120) }
            .screenBackground()
            .navigationTitle("Radar am Standort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ d: NowcastDetailResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headline(d.summary)).font(.title3.weight(.semibold))
            if let text = d.summary?.text { Text(text).font(.footnote).opacity(0.9) }
        }
        .card()
        if let r = d.radar5min {
            // time = end of the 5-minute interval (the bars end there)
            let times = r.time.map { Fmt.parse($0) }
            let n = r.time.count
            let dates = times.compactMap { $0 }
            if let first = dates.first, let last = dates.last, last > first {
                TimeChart(
                    title: "Regenrate in 5-Minuten-Schritten",
                    subtitle: r.nowcastFrom.flatMap { Fmt.parse($0) }.map { "Ab \(Fmt.time($0)) Uhr Prognose des DWD (Nowcast)" },
                    unit: "mm/h",
                    series: [
                        ChartSeries("Standort", color: Palette.rain, style: .bars, times: times, values: r.pointMmH?.expanded(n) ?? []),
                        ChartSeries("±1 km höchster", color: .white, times: times, values: r.nearMaxMmH?.expanded(n) ?? []),
                        ChartSeries("±3 km höchster", color: Palette.sun, dashed: true, times: times, values: r.areaMaxMmH?.expanded(n) ?? []),
                    ],
                    domain: first...last,
                    zeroBased: true,
                    minSpan: 1,
                    decimals: 1,
                    height: 170,
                    now: Fmt.parse(d.summary?.radarAnalysis),
                    barWidth: 300,
                    zeroText: "kein Niederschlag im Zeitraum"
                )
            }
        }
        episodesCard(d.episodes ?? [])
        if let m = d.modelComparison15min, let mt = m.time, !mt.isEmpty {
            let times = mt.map { Fmt.parse($0) }
            let dates = times.compactMap { $0 }
            if let first = dates.first, let last = dates.last, last > first {
                TimeChart(
                    title: "Radar gegen Modell je 15 Minuten",
                    subtitle: "Summe: Radar \(Fmt.precip(m.radarTotalMm)), \(ModelNames.short("icon_d2")) \(Fmt.precip(m.modelTotalMm))",
                    unit: "mm",
                    series: [
                        ChartSeries("Radar", color: Palette.rain, style: .bars, times: times, values: m.radarMm?.expanded(mt.count) ?? []),
                        ChartSeries("ICON-D2", color: Palette.model("icon"), style: .points, times: times, values: m.modelMm?.expanded(mt.count) ?? []),
                    ],
                    domain: first.addingTimeInterval(-900)...last,
                    zeroBased: true,
                    minSpan: 0.5,
                    decimals: 1,
                    barWidth: 900,
                    zeroText: "beide trocken"
                )
            }
        }
    }

    private func headline(_ s: NowcastResponse.Summary?) -> String {
        guard let s else { return "Keine Radardaten" }
        if s.rainingNow == true {
            if let end = Fmt.parse(s.rainEnd) { return "Es regnet bis etwa \(Fmt.time(end))" }
            return "Es regnet"
        }
        if let start = Fmt.parse(s.rainStart) { return "Regen ab etwa \(Fmt.time(start))" }
        if let until = Fmt.parse(s.nowcastUntil) { return "Trocken bis \(Fmt.time(until))" }
        return "Trocken"
    }

    @ViewBuilder
    private func episodesCard(_ episodes: [NowcastDetailResponse.Episode]) -> some View {
        if !episodes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle("Regenphasen", systemImage: "cloud.rain")
                ForEach(Array(episodes.enumerated()), id: \.offset) { _, e in
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(time(e.start)) – \(time(e.end))").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text([Fmt.precip(e.mm), e.peakMmH.map { "bis " + Fmt.rate($0) }, e.intensity].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .opacity(0.85)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .card()
        }
    }

    /// Clock time for ISO values, the server's words otherwise ("vor Fensterbeginn").
    private func time(_ text: String?) -> String {
        guard let text else { return "–" }
        return Fmt.parse(text).map { Fmt.time($0) } ?? text
    }
}
