import Charts
import SwiftUI

extension Endpoint {
    static let trend = Endpoint(path: "/api/v1/tools/weather_trend", mock: "mock_trend")
}

/// Trend beyond the first week: days 8-16 of the ensembles and weeks 3-6 as deviations from normal.
struct TrendScreen: View {
    @StateObject private var loader = Loader<TrendResponse>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    TrendContent(data: data)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Wetterdaten: Open-Meteo.com (CC BY 4.0), ECMWF ENS/EC46, NOAA GEFS")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.reload()
        }
        .task { await loader.loadIfNeeded(.trend, maxAge: 1800) }
        .screenBackground()
        .navigationTitle("Trend")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TrendContent: View {
    let data: TrendResponse

    private struct DayPoint: Identifiable {
        let id: String
        let date: Date
        let p10: Double?
        let p50: Double?
        let p90: Double?
        let gefs: Double?
        let normal: Double?
    }

    private var points: [DayPoint] {
        (data.days816 ?? []).compactMap { day in
            guard let d = Fmt.parse(day.date) else { return nil }
            return DayPoint(
                id: day.date,
                date: d.addingTimeInterval(12 * 3600),
                p10: day.ecmwf?.tmaxC?[0],
                p50: day.ecmwf?.tmaxC?[1],
                p90: day.ecmwf?.tmaxC?[2],
                gefs: day.gefs?.tmaxC?[1],
                normal: day.normal?.tmaxC
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !points.isEmpty { daysChart }
            ForEach(Array((data.blocks ?? []).enumerated()), id: \.offset) { _, block in
                blockCard(block)
            }
            if let weeks = data.weeks, !weeks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    CardTitle("Wochen 2 bis 6", systemImage: "calendar", info: "ec46")
                    GlossaryNotesView(["polarwirbel", "nao", "ao"])
                    ForEach(weeks) { week in
                        weekRow(week)
                        Divider().overlay(.white.opacity(0.15))
                    }
                }
                .card()
            }
        }
    }

    private var daysChart: some View {
        let pts = points
        let values = pts.flatMap { [$0.p10, $0.p90, $0.gefs, $0.normal].compactMap { $0 } }
        let lo = (values.min() ?? 0) - 1
        let hi = (values.max() ?? 1) + 1
        return VStack(alignment: .leading, spacing: 8) {
            CardTitle("Höchstwerte Tag 8 bis 16", systemImage: "chart.line.uptrend.xyaxis", info: "anomalie")
            HStack(spacing: 10) {
                legend(Palette.warm.opacity(0.5), "ECMWF 80 %")
                legend(Palette.warm, "ECMWF")
                legend(Palette.model("gfs"), "GEFS")
                legend(.white.opacity(0.7), "normal")
            }
            Text("Fläche: 80 % der ECMWF-Läufe (10 bis 90 %), Linien: Median der Ensembles, gepunktet: Klimamittel.")
                .font(.caption2)
                .opacity(0.7)
            Chart {
                ForEach(pts) { p in
                    if let a = p.p10, let b = p.p90 {
                        AreaMark(x: .value("Tag", p.date), yStart: .value("P10", a), yEnd: .value("P90", b))
                            .foregroundStyle(Palette.warm.opacity(0.3))
                    }
                }
                ForEach(pts) { p in
                    if let v = p.p50 {
                        LineMark(x: .value("Tag", p.date), y: .value("°C", v), series: .value("Reihe", "ECMWF"))
                            .foregroundStyle(Palette.warm)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("Tag", p.date), y: .value("°C", v))
                            .foregroundStyle(Palette.warm)
                            .symbolSize(20)
                    }
                }
                ForEach(pts) { p in
                    if let v = p.gefs {
                        LineMark(x: .value("Tag", p.date), y: .value("°C", v), series: .value("Reihe", "GEFS"))
                            .foregroundStyle(Palette.model("gfs"))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                }
                ForEach(pts) { p in
                    if let v = p.normal {
                        LineMark(x: .value("Tag", p.date), y: .value("°C", v), series: .value("Reihe", "normal"))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                    }
                }
            }
            .chartYScale(domain: lo...hi)
            .chartXAxis {
                AxisMarks(values: pts.map(\.date)) { value in
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(Fmt.weekdayShort(d)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.number(v, decimals: 0) + "°").foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .frame(height: 200)
            .accessibilityLabel("Höchstwerte Tag 8 bis 16")
        }
        .card()
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 12, height: 6)
            Text(text).font(.caption2).fixedSize()
        }
    }

    private func blockCard(_ b: TrendResponse.Block) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tag \(b.days ?? "–")").font(.headline)
                Spacer()
                if let level = b.confidence?.level {
                    ConfidenceBadge(level: ReportWords.confidenceLevel(level) ?? "niedrig", word: level)
                }
            }
            Text(period(b.from, b.to)).font(.caption).opacity(0.8)
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Höchstwert vs. normal", value: "ECMWF \(signed(b.ecmwfTmaxAnomalyK)) K\nGEFS \(signed(b.gefsTmaxAnomalyK)) K")
                Fact(label: "Regenrisiko", value: "ECMWF \(Fmt.percent(b.ecmwfRainProbPct))\nGEFS \(Fmt.percent(b.gefsRainProbPct))\nnormal \(Fmt.percent(b.normalRainProbPct))")
            }
            if let why = b.confidence?.why {
                Text(why).font(.caption).opacity(0.75)
            }
        }
        .card()
    }

    private func weekRow(_ w: TrendResponse.Week) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(period(w.from, w.to)).font(.subheadline.weight(.semibold))
                Spacer()
                if let a = w.tAnomalyK {
                    Text("\(signed(a)) K")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(a >= 0 ? Palette.warm : Palette.cold)
                }
            }
            if let signal = w.signal {
                Text(signal.prefix(1).uppercased() + signal.dropFirst()).font(.callout)
            }
            Text(weekFacts(w)).font(.caption).opacity(0.8)
            if let c = w.confidence {
                Text("Konfidenz \(c.level ?? "–")\(c.why.map { ": \($0)" } ?? "")").font(.caption2).opacity(0.7)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func weekFacts(_ w: TrendResponse.Week) -> String {
        var parts: [String] = []
        if let t = w.tMeanC { parts.append("Mittel \(Fmt.temp(t, decimals: 1))") }
        if let p = w.pWarmerPct { parts.append("wärmer als normal: \(Fmt.percent(p))") }
        if let r = w.precipWeekMm { parts.append("Niederschlag \(Fmt.precip(r)) (\(signed(w.precipAnomalyMm)) mm)") }
        if let p = w.pWetterPct { parts.append("nasser als normal: \(Fmt.percent(p))") }
        return parts.joined(separator: " · ")
    }

    private func signed(_ v: Double?) -> String {
        guard let v else { return "–" }
        let text = Fmt.number(v, decimals: 1)
        return v > 0 ? "+" + text : text
    }

    private func period(_ from: String?, _ to: String?) -> String {
        guard let a = Fmt.parse(from), let b = Fmt.parse(to) else { return "" }
        return "\(Fmt.weekdayShort(a)) \(Fmt.dayMonth(a)) bis \(Fmt.weekdayShort(b)) \(Fmt.dayMonth(b))"
    }
}
