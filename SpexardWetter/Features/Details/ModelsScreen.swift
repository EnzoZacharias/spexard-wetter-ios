import Charts
import SwiftUI

extension Endpoint {
    static let modelHours = Endpoint(path: "/api/v1/modelle/stunden", mock: "mock_modelle_stunden")
}

enum ModelVariable: String, CaseIterable, Identifiable {
    case temp, precip, wind, gust, cloud

    var id: String { rawValue }

    var label: String {
        switch self {
        case .temp: return "Temperatur"
        case .precip: return "Regen"
        case .wind: return "Wind"
        case .gust: return "Böen"
        case .cloud: return "Wolken"
        }
    }

    var unit: String {
        switch self {
        case .temp: return "°C"
        case .precip: return "mm je Stunde"
        case .wind, .gust: return "km/h"
        case .cloud: return "%"
        }
    }

    func series(_ m: ModelHoursResponse.ModelSeries) -> Series<Double>? {
        switch self {
        case .temp: return m.tC
        case .precip: return m.precipMm
        case .wind: return m.windKmh
        case .gust: return m.gustKmh
        case .cloud: return m.cloudPct
        }
    }
}

/// The deterministic models side by side: hourly curves per model and the daily values.
struct ModelsScreen: View {
    @StateObject private var loader = Loader<ModelHoursResponse>()
    @State private var variable: ModelVariable = .temp
    @State private var hiddenModels: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Größe", selection: $variable) {
                    ForEach(ModelVariable.allCases) { v in
                        Text(v.label).tag(v)
                    }
                }
                .pickerStyle(.segmented)

                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    content(data)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Wetterdaten: Open-Meteo.com (CC BY 4.0)")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.reload()
        }
        .task { await loader.loadIfNeeded(.modelHours, maxAge: 900) }
        .screenBackground()
        .navigationTitle("Modellvergleich")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(_ data: ModelHoursResponse) -> some View {
        let times = ChartTime.dates(data.time)
        let n = data.time.count
        let dates = times.compactMap { $0 }
        if let first = dates.first, let last = dates.last, last > first {
            let ids = data.modelIds
            let series = ids.filter { !hiddenModels.contains($0) }.compactMap { id -> ChartSeries? in
                guard let m = data.models[id], let s = variable.series(m) else { return nil }
                return ChartSeries(
                    data.label(id),
                    color: Palette.model(id),
                    times: times,
                    values: s.expanded(n)
                )
            }
            TimeChart(
                title: "\(variable.label) je Modell",
                subtitle: "Jedes Modell eine Linie; Lücke = Modell rechnet so weit nicht.",
                unit: variable.unit,
                series: series,
                domain: first...last,
                zeroBased: variable != .temp,
                minSpan: variable == .temp ? 4 : (variable == .cloud ? 100 : 2),
                decimals: variable == .precip ? 1 : 0,
                height: 200
            )
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ids, id: \.self) { id in
                        Button {
                            if hiddenModels.contains(id) { hiddenModels.remove(id) } else { hiddenModels.insert(id) }
                            Haptics.selection()
                        } label: {
                            HStack(spacing: 4) {
                                Circle().fill(Palette.model(id)).frame(width: 8, height: 8)
                                Text(data.label(id)).font(.caption.weight(.semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(hiddenModels.contains(id) ? 0.05 : 0.18)))
                            .opacity(hiddenModels.contains(id) ? 0.5 : 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(data.label(id)) \(hiddenModels.contains(id) ? "einblenden" : "ausblenden")")
                    }
                }
            }
            .scrollIndicators(.hidden)
            if let summary = data.summary {
                spread(summary, times: times, n: n, domain: first...last)
            }
            DailyModelTable(data: data)
        } else {
            StateMessage(kind: .empty, text: "Keine Stundenwerte der Modelle").card()
        }
    }

    @ViewBuilder
    private func spread(_ s: ModelHoursResponse.Summary, times: [Date?], n: Int, domain: ClosedRange<Date>) -> some View {
        switch variable {
        case .temp:
            TimeChart(
                title: "Spanne der Modelle",
                subtitle: "Tiefster und höchster Modellwert je Stunde, dazwischen der Mittelwert des Servers",
                unit: "°C",
                series: [
                    ChartSeries("höchster", color: Palette.warm, dashed: true, times: times, values: s.tMaxC?.expanded(n) ?? []),
                    ChartSeries("Mittel", color: .white, times: times, values: s.tC?.expanded(n) ?? []),
                    ChartSeries("tiefster", color: Palette.cold, dashed: true, times: times, values: s.tMinC?.expanded(n) ?? []),
                ],
                domain: domain,
                minSpan: 4
            )
        case .precip:
            TimeChart(
                title: "Regen: Mittel und Höchstwert der Modelle",
                unit: "mm je Stunde",
                series: [
                    ChartSeries("Mittel", color: Palette.rain, style: .bars, times: times, values: s.precipMm?.expanded(n) ?? []),
                    ChartSeries("höchster", color: .white, style: .points, times: times, values: s.precipMaxMm?.expanded(n) ?? []),
                ],
                domain: domain,
                zeroBased: true,
                minSpan: 1,
                decimals: 1
            )
        default:
            EmptyView()
        }
    }
}

/// Daily minimum, maximum and rain per model (`days` of the answer).
struct DailyModelTable: View {
    let data: ModelHoursResponse

    var body: some View {
        let ids = data.modelIds.filter { !(data.days?[$0] ?? []).isEmpty }
        let dates = Array(Set(ids.flatMap { id in (data.days?[id] ?? []).map(\.date) })).sorted()
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Tageswerte je Modell", systemImage: "tablecells")
            ScrollView(.horizontal) {
                Grid(alignment: .trailing, horizontalSpacing: 14, verticalSpacing: 6) {
                    GridRow {
                        Text("Tag").gridColumnAlignment(.leading)
                        ForEach(ids, id: \.self) { id in
                            Text(data.label(id)).foregroundStyle(Palette.model(id))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    ForEach(dates, id: \.self) { date in
                        GridRow {
                            Text(dayLabel(date)).font(.caption.weight(.semibold))
                            ForEach(ids, id: \.self) { id in
                                let day = data.days?[id]?.first { $0.date == date }
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(Fmt.temp(day?.tminC)) / \(Fmt.temp(day?.tmaxC))")
                                    Text(Fmt.precip(day?.precipMm)).opacity(0.75)
                                }
                                .font(.caption.monospacedDigit())
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            Text("Tiefst- / Höchstwert und Niederschlag je Tag").font(.caption2).opacity(0.7)
        }
        .card()
    }

    private func dayLabel(_ text: String) -> String {
        guard let d = Fmt.parse(text) else { return text }
        return "\(Fmt.weekdayShort(d)) \(Fmt.dayMonth(d))"
    }
}
