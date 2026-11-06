import SwiftUI

struct DaySelection: Identifiable {
    let id: String
}

/// One day in detail (tap on a day row): ensemble range, every model's values and the hourly
/// curve where the hourly forecast reaches.
struct DayDetailSheet: View {
    let dayId: String
    let model: HomeModel
    @Environment(\.dismiss) private var dismiss

    private var day: ForecastResponse.Day? { model.forecast?.days.first { $0.date == dayId } }
    private var item: DayItem? { model.days.first { $0.id == dayId } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let item { header(item) }
                    if let ens = day?.ecmwfEns { ensembleCard(ens) }
                    if let models = day?.models, !models.isEmpty { modelsCard(models) }
                    hourly
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var title: String {
        guard let d = Fmt.parse(dayId) else { return dayId }
        return Fmt.longDate(d)
    }

    private func header(_ item: DayItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 44))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).font(.title2.weight(.semibold))
                Text("Max \(Fmt.temp(item.tmax)) · Min \(Fmt.temp(item.tmin))").font(.headline)
                if let p = item.rainProb {
                    Text("Regenrisiko \(Fmt.percent(p))").font(.subheadline).foregroundStyle(Palette.rain)
                }
            }
            Spacer()
            if let level = item.confidence {
                ConfidenceBadge(level: ReportWords.confidenceLevel(level) ?? level, word: level)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func ensembleCard(_ e: ForecastResponse.Ensemble) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("ECMWF-Ensemble", systemImage: "point.3.filled.connected.trianglepath.dotted")
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Höchstwert (80 % der Läufe)", value: range(e.tmaxC))
                Fact(label: "Tiefstwert (80 % der Läufe)", value: range(e.tminC))
            }
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Niederschlag Median", value: Fmt.precip(e.precipMm?[1]))
                Fact(label: "Regen ab 1 mm", value: Fmt.percent(e.rainProbPct))
                Fact(label: "Überhaupt Regen", value: Fmt.percent(e.rainAnyProbPct))
            }
        }
        .card()
    }

    private func range(_ s: Series<Double>?) -> String {
        guard let s, let lo = s[0], let hi = s[2] else { return Fmt.temp(s?[1]) }
        return "\(Fmt.temp(lo, decimals: 1)) bis \(Fmt.temp(hi, decimals: 1))"
    }

    private func modelsCard(_ models: [String: ForecastResponse.ModelDay?]) -> some View {
        let order = ["icon", "ecmwf", "gfs", "ukmo"]
        let ids = models.keys.sorted { (order.firstIndex(of: $0) ?? 9, $0) < (order.firstIndex(of: $1) ?? 9, $1) }
        return VStack(alignment: .leading, spacing: 8) {
            CardTitle("Die Modelle", systemImage: "square.stack.3d.up")
            ForEach(ids, id: \.self) { id in
                if let m = models[id] ?? nil {
                    HStack(spacing: 10) {
                        Circle().fill(Palette.model(id)).frame(width: 8, height: 8)
                        Text(ModelNames.short(id)).font(.subheadline.weight(.semibold)).frame(width: 62, alignment: .leading)
                        Image(systemName: WeatherSymbol.name(text: m.weather, night: false))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Fmt.temp(m.tminC)) / \(Fmt.temp(m.tmaxC))").font(.subheadline.monospacedDigit())
                            Text(m.weather ?? "").font(.caption2).opacity(0.75).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(Fmt.precip(m.precipMm)).font(.caption.monospacedDigit())
                            Text("Böen \(Fmt.wind(m.gustKmh))").font(.caption2).opacity(0.75)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private var hourly: some View {
        if let h = model.hours?.hours, let start = Fmt.parse(dayId) {
            let end = start.addingTimeInterval(24 * 3600)
            let times = ChartTime.dates(h.time.values.map { $0 ?? "" })
            let inDay = times.map { t -> Date? in
                guard let t, t >= start, t <= end else { return nil }
                return t
            }
            if inDay.compactMap({ $0 }).count > 2 {
                let n = h.time.count
                TimeChart(
                    title: "Temperatur Stunde für Stunde",
                    unit: "°C",
                    series: [ChartSeries("Temperatur", color: Palette.warm, times: inDay, values: h.tC.expanded(n))],
                    domain: start...end,
                    nights: ChartTime.nights((model.hours?.sun ?? []).map { ($0.date, $0.sunrise, $0.sunset) }, within: start...end),
                    minSpan: 4
                )
                TimeChart(
                    title: "Niederschlag",
                    unit: "mm je Stunde",
                    series: [ChartSeries("Niederschlag", color: Palette.rain, style: .bars, times: inDay, values: h.precipMm.expanded(n))],
                    domain: start...end,
                    zeroBased: true,
                    minSpan: 1,
                    decimals: 1
                )
            }
        }
    }
}
