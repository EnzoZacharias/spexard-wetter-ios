import Charts
import SwiftUI

enum EnsembleView: String, CaseIterable, Identifiable {
    case ecmwf, gefs, regen, tage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ecmwf: return "ECMWF"
        case .gefs: return "GEFS"
        case .regen: return "Regen"
        case .tage: return "Tage"
        }
    }
}

/// Ensembles: temperature plumes of ECMWF and GEFS, rain chances of ICON-D2-EPS and the
/// certainty per day.
struct EnsemblesScreen: View {
    @State private var view: EnsembleView = LaunchArgs.option.flatMap(EnsembleView.init(rawValue:)) ?? .ecmwf
    @StateObject private var temp = Loader<EnsembleTempResponse>()
    @StateObject private var rain = Loader<EnsembleRainResponse>()
    @StateObject private var days = Loader<EnsembleDaysResponse>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Ansicht", selection: $view) {
                    ForEach(EnsembleView.allCases) { v in
                        Text(v.label).tag(v)
                    }
                }
                .pickerStyle(.segmented)

                switch view {
                case .ecmwf, .gefs:
                    loaded(temp) { PlumeCard(data: $0) }
                case .regen:
                    loaded(rain) { RainChanceCard(data: $0) }
                case .tage:
                    loaded(days) { CertaintyCard(data: $0) }
                }
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await reload(force: true)
        }
        .task(id: view) { await reload(force: false) }
        .screenBackground()
        .navigationTitle("Ensembles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reload(force: Bool) async {
        switch view {
        case .ecmwf, .gefs:
            let e = Endpoint(path: "/api/v1/ensembles/temperatur?modell=\(view.rawValue)", mock: "mock_ensembles_temperatur_\(view.rawValue)")
            if force { await temp.load(e) } else { await temp.loadIfNeeded(e, maxAge: 1800) }
        case .regen:
            let e = Endpoint(path: "/api/v1/ensembles/regen", mock: "mock_ensembles_regen")
            if force { await rain.load(e) } else { await rain.loadIfNeeded(e, maxAge: 1800) }
        case .tage:
            let e = Endpoint(path: "/api/v1/ensembles/tage", mock: "mock_ensembles_tage")
            if force { await days.load(e) } else { await days.loadIfNeeded(e, maxAge: 1800) }
        }
    }

    @ViewBuilder
    private func loaded<T: Decodable, Content: View>(_ loader: Loader<T>, @ViewBuilder content: (T) -> Content) -> some View {
        if loader.fromCache { OfflineBanner(date: loader.date) }
        if let value = loader.value {
            content(value).opacity(loader.loading ? 0.6 : 1)
        } else if let error = loader.error {
            StateMessage(kind: .error, text: error) { await loader.reload() }.card()
        } else {
            StateMessage(kind: .loading).card()
        }
        StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Wetterdaten: Open-Meteo.com (CC BY 4.0), Ensembles von ECMWF, NOAA und DWD")
    }
}

/// All members as thin lines, the 10-90 % band and the median.
struct PlumeCard: View {
    let data: EnsembleTempResponse

    private struct Line: Identifiable {
        let id: Int
        let points: [ChartSeries.Point]
    }

    var body: some View {
        let times = ChartTime.dates(data.time)
        let n = data.time.count
        let p10 = data.p10?.expanded(n) ?? []
        let p50 = data.p50?.expanded(n) ?? []
        let p90 = data.p90?.expanded(n) ?? []
        let members: [Line] = (data.members ?? []).enumerated().map { i, s in
            Line(id: i, points: ChartSeries("m\(i)", color: .white, times: times, values: s.expanded(n)).points)
        }
        let band: [(Date, Double, Double)] = times.indices.compactMap { i in
            guard let d = times[i], p10.indices.contains(i), p90.indices.contains(i), let a = p10[i], let b = p90[i] else { return nil }
            return (d, a, b)
        }
        let median = ChartSeries("Median", color: .white, times: times, values: p50)
        let all = members.flatMap { $0.points.map(\.value) } + band.flatMap { [$0.1, $0.2] }
        let lo = (all.min() ?? 0) - 1
        let hi = (all.max() ?? 1) + 1
        let dates = times.compactMap { $0 }
        VStack(alignment: .leading, spacing: 8) {
            Text(data.model?.label ?? "Ensemble").font(.headline)
            Text("Temperatur in 2 m: jede dünne Linie ist ein Lauf (\(data.model?.members ?? members.count) Läufe), die Fläche umfasst 80 % der Läufe (10 bis 90 %), die dicke Linie ist der Median.")
                .font(.caption)
                .opacity(0.8)
            if let first = dates.first, let last = dates.last, last > first {
                Chart {
                    ForEach(members) { line in
                        ForEach(line.points) { p in
                            LineMark(x: .value("Zeit", p.date), y: .value("Temperatur", p.value), series: .value("Lauf", "m\(line.id)"))
                                .foregroundStyle(Palette.cold.opacity(0.18))
                                .lineStyle(StrokeStyle(lineWidth: 0.7))
                        }
                    }
                    ForEach(Array(band.enumerated()), id: \.offset) { _, b in
                        AreaMark(x: .value("Zeit", b.0), yStart: .value("P10", b.1), yEnd: .value("P90", b.2))
                            .foregroundStyle(Palette.warm.opacity(0.28))
                    }
                    ForEach(median.points) { p in
                        LineMark(x: .value("Zeit", p.date), y: .value("Temperatur", p.value), series: .value("Lauf", "Median"))
                            .foregroundStyle(.white)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartXScale(domain: first...last)
                .chartYScale(domain: lo...hi)
                .chartXAxis {
                    AxisMarks(values: ChartTime.ticks(from: first, to: last)) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.12))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(ChartTime.label(date, daily: last.timeIntervalSince(first) >= 80 * 3600)).foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.12))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Fmt.number(v, decimals: 0) + "°").foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }
                .frame(height: 260)
                .accessibilityLabel("Temperaturfahne des Ensembles")
                .accessibilityValue("Median von \(Fmt.temp(median.points.map(\.value).min())) bis \(Fmt.temp(median.points.map(\.value).max()))")
            } else {
                StateMessage(kind: .empty, text: "Keine Läufe im Zeitraum")
            }
        }
        .card()
    }
}

/// Share of ICON-D2-EPS members above the rain thresholds per hour.
struct RainChanceCard: View {
    let data: EnsembleRainResponse

    private static let colors: [Color] = [
        Color(red: 0.62, green: 0.86, blue: 1.0),
        Color(red: 0.35, green: 0.65, blue: 1.0),
        Color(red: 0.25, green: 0.40, blue: 0.95),
        Color(red: 0.70, green: 0.35, blue: 0.95),
    ]

    var body: some View {
        let times = ChartTime.dates(data.time)
        let n = data.time.count
        let dates = times.compactMap { $0 }
        let series: [ChartSeries] = (data.pct ?? []).enumerated().map { i, s in
            let label = (data.thresholds ?? []).indices.contains(i) ? (data.thresholds?[i].label ?? "Stufe \(i + 1)") : "Stufe \(i + 1)"
            return ChartSeries(label, color: Self.colors[min(i, Self.colors.count - 1)], style: i == 0 ? .area : .line, times: times, values: s.expanded(n))
        }
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.label ?? "Regen-Ensemble").font(.headline)
                Text("Anteil der \(data.membersCount.map(String.init) ?? "") Läufe mit mehr Regen als die Schwelle, je Stunde.")
                    .font(.caption)
                    .opacity(0.8)
            }
            .card()
            if let first = dates.first, let last = dates.last, last > first {
                TimeChart(
                    title: "Wahrscheinlichkeit für Regen",
                    unit: "% der Läufe",
                    series: series,
                    domain: first...last,
                    zeroBased: true,
                    minSpan: 100,
                    height: 200
                )
                TimeChart(
                    title: "Regenmenge im Ensemble",
                    unit: "mm je Stunde",
                    series: [
                        ChartSeries("Median", color: Palette.rain, style: .bars, times: times, values: data.p50?.expanded(n) ?? []),
                        ChartSeries("stärkster Lauf", color: .white, style: .points, times: times, values: data.max?.expanded(n) ?? []),
                    ],
                    domain: first...last,
                    zeroBased: true,
                    minSpan: 1,
                    decimals: 1
                )
            } else {
                StateMessage(kind: .empty, text: "Keine Stundenwerte").card()
            }
        }
    }
}

/// How sure the ensembles are per day: 10-90 % range of the maximum and the rain words.
struct CertaintyCard: View {
    let data: EnsembleDaysResponse

    var body: some View {
        let rows = data.certainty ?? []
        let lows = rows.compactMap(\.tmaxP10)
        let highs = rows.compactMap(\.tmaxP90)
        let range = (lows.min() ?? 0)...max((highs.max() ?? 1), (lows.min() ?? 0) + 1)
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Sicherheit je Tag", systemImage: "scope")
            Text("Balken: Höchstwert, in dem 80 % der Läufe liegen (10 bis 90 %), Strich = Median.")
                .font(.caption)
                .opacity(0.8)
            if rows.isEmpty {
                StateMessage(kind: .empty, text: "Keine Tageswerte")
            }
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(dayLabel(row)).font(.subheadline.weight(.semibold))
                        Text(ModelNames.short(row.source ?? "")).font(.caption2).opacity(0.7)
                    }
                    .frame(width: 70, alignment: .leading)
                    RangeBar(low: row.tmaxP10, mid: row.tmaxP50, high: row.tmaxP90, range: range)
                        .frame(height: 14)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Fmt.temp(row.tmaxP10))–\(Fmt.temp(row.tmaxP90))").font(.caption.monospacedDigit().weight(.semibold))
                        Text(row.spread.map { "Streuung \($0)" } ?? "").font(.caption2).opacity(0.75)
                    }
                    .frame(width: 92, alignment: .trailing)
                }
                if let words = row.rainWords {
                    Text("Regen ab 1 mm: \(words)\(row.rain1mmPct.map { " (\(Fmt.number($0, decimals: 0)) %)" } ?? "")")
                        .font(.caption)
                        .opacity(0.85)
                        .padding(.leading, 80)
                }
                Divider().overlay(.white.opacity(0.15))
            }
        }
        .card()
    }

    private func dayLabel(_ row: EnsembleDaysResponse.Certainty) -> String {
        guard let d = Fmt.parse(row.date) else { return row.weekday ?? row.date }
        return "\(Fmt.weekdayShort(d)) \(Fmt.dayMonth(d))"
    }
}

struct RangeBar: View {
    let low: Double?
    let mid: Double?
    let high: Double?
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let span = max(range.upperBound - range.lowerBound, 0.1)
            let x = { (v: Double) in geo.size.width * CGFloat((v - range.lowerBound) / span) }
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                if let low, let high {
                    Capsule()
                        .fill(LinearGradient(colors: [TempBar.color(low), TempBar.color(high)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(x(high) - x(low), 6))
                        .offset(x: x(low))
                }
                if let mid {
                    Rectangle().fill(.white).frame(width: 2).offset(x: x(mid) - 1)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
