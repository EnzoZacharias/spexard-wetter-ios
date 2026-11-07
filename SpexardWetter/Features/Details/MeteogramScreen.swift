import Charts
import SwiftUI

enum MeteogramModel: String, CaseIterable, Identifiable {
    case icon_d2, arome, ecmwf, gfs

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon_d2: return "ICON-D2"
        case .arome: return "AROME"
        case .ecmwf: return "ECMWF"
        case .gfs: return "GFS"
        }
    }

    var endpoint: Endpoint {
        Endpoint(path: "/api/v1/meteogramm/modell?modell=\(rawValue)", mock: "mock_meteogramm_\(rawValue)")
    }
}

/// Hour by hour forecast of one model: stacked charts on one time axis.
struct MeteogramScreen: View {
    @StateObject private var loader = Loader<MeteogramResponse>()
    @AppStorage("meteogrammModell") private var model: MeteogramModel = LaunchArgs.option.flatMap(MeteogramModel.init(rawValue:)) ?? .icon_d2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Modell", selection: $model) {
                    ForEach(MeteogramModel.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    MeteogramContent(data: data)
                        .opacity(loader.loading ? 0.6 : 1)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Wetterdaten: Open-Meteo.com (CC BY 4.0), Modelle von DWD, ECMWF, NOAA und Météo-France")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.load(model.endpoint)
        }
        .task(id: model) { await loader.loadIfNeeded(model.endpoint, maxAge: 900) }
        .screenBackground()
        .navigationTitle("Meteogramm")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MeteogramContent: View {
    let data: MeteogramResponse

    private var times: [Date?] { ChartTime.dates(data.hourly.time) }
    private var n: Int { data.hourly.time.count }

    private var domain: ClosedRange<Date>? {
        let d = times.compactMap { $0 }
        guard let a = d.first, let b = d.last, b > a else { return nil }
        return a...b
    }

    private var nights: [ClosedRange<Date>] {
        guard let domain else { return [] }
        return ChartTime.nights((data.days ?? []).map { ($0.date, $0.sunrise, $0.sunset) }, within: domain)
    }

    private func values(_ s: Series<Double>?) -> [Double?] { s?.expanded(n) ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let model = data.model {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.label ?? model.id ?? "Modell").font(.headline)
                    Text(modelNote(model)).font(.caption).opacity(0.8)
                }
                .card()
            }
            if let domain {
                SymbolStrip(times: times, codes: data.hourly.weatherCode?.expanded(n) ?? [], nights: nights, domain: domain)
                TimeChart(
                    title: "Temperatur und Taupunkt",
                    unit: "°C",
                    series: [
                        ChartSeries("Temperatur", color: Palette.warm, times: times, values: values(data.hourly.tC)),
                        ChartSeries("Taupunkt", color: Palette.cold, dashed: true, times: times, values: values(data.hourly.dewPointC)),
                    ],
                    domain: domain,
                    nights: nights,
                    minSpan: 4,
                    info: "taupunkt",
                    notes: ["frost", "bodenfrost", "glaette", "nebel"]
                )
                TimeChart(
                    title: "Niederschlag",
                    unit: "mm je Stunde",
                    series: [ChartSeries("Niederschlag", color: Palette.rain, style: .bars, times: times, values: values(data.hourly.precipMm))],
                    domain: domain,
                    nights: nights,
                    zeroBased: true,
                    minSpan: 1,
                    decimals: 1,
                    barWidth: 3600,
                    zeroText: "kein Niederschlag im Zeitraum",
                    info: "niederschlagsmenge"
                )
                TimeChart(
                    title: "Wind und Böen",
                    unit: "km/h",
                    series: [
                        ChartSeries("Wind", color: Palette.wind, times: times, values: values(data.hourly.windKmh)),
                        ChartSeries("Böen", color: .white, dashed: true, times: times, values: values(data.hourly.gustKmh)),
                    ],
                    domain: domain,
                    nights: nights,
                    zeroBased: true,
                    minSpan: 20,
                    info: "boee",
                    notes: ["boee", "llj"]
                )
                TimeChart(
                    title: "Bewölkung",
                    unit: "%",
                    series: [
                        ChartSeries("tief", color: Color.white.opacity(0.9), style: .area, times: times, values: values(data.hourly.cloudLowPct)),
                        ChartSeries("mittel", color: Color(red: 0.7, green: 0.8, blue: 1.0), style: .area, times: times, values: values(data.hourly.cloudMidPct)),
                        ChartSeries("hoch", color: Color(red: 0.6, green: 0.6, blue: 0.9), style: .area, times: times, values: values(data.hourly.cloudHighPct)),
                    ].filter { !$0.isEmpty },
                    domain: domain,
                    nights: nights,
                    zeroBased: true,
                    minSpan: 100,
                    info: "bewoelkung",
                    notes: ["inversion"]
                )
                TimeChart(
                    title: "Luftdruck",
                    unit: "hPa",
                    series: [ChartSeries("Luftdruck", color: Color(red: 0.85, green: 0.75, blue: 1.0), times: times, values: values(data.hourly.pressureHpa))],
                    domain: domain,
                    nights: nights,
                    minSpan: 6,
                    info: "luftdruck",
                    notes: ["drucktendenz"]
                )
                let sun = values(data.hourly.sunMin)
                if sun.contains(where: { ($0 ?? 0) > 0 }) {
                    TimeChart(
                        title: "Sonnenschein",
                        unit: "min je Stunde",
                        series: [ChartSeries("Sonne", color: Palette.sun, style: .bars, times: times, values: sun)],
                        domain: domain,
                        nights: nights,
                        zeroBased: true,
                        minSpan: 60,
                        barWidth: 3600
                    )
                }
                let cape = values(data.hourly.capeJkg)
                if cape.contains(where: { ($0 ?? 0) >= 100 }) {
                    TimeChart(
                        title: "Gewitterenergie (CAPE)",
                        unit: "J/kg",
                        series: [ChartSeries("CAPE", color: Color(red: 1.0, green: 0.5, blue: 0.4), style: .area, times: times, values: cape)],
                        domain: domain,
                        nights: nights,
                        zeroBased: true,
                        minSpan: 200,
                        info: "cape",
                        notes: ["cape", "lifted_index"]
                    )
                }
            } else {
                StateMessage(kind: .empty, text: "Keine Stundenwerte vom Modell").card()
            }
        }
    }

    private func modelNote(_ model: MeteogramResponse.Model) -> String {
        var parts: [String] = []
        if let h = model.heightM { parts.append("Modellhöhe \(Fmt.number(h, decimals: 0)) m") }
        if let until = Fmt.parse(model.dataUntil) { parts.append("Daten bis \(Fmt.relativeDateTime(until, reference: Date()))") }
        for step in model.steps ?? [] {
            if let from = Fmt.parse(step.from), let hours = step.hours {
                parts.append("ab \(Fmt.relativeDateTime(from, reference: Date())) nur alle \(hours) Stunden gerechnet")
            }
        }
        return parts.joined(separator: " · ")
    }
}

/// Weather symbols every few hours above the charts.
struct SymbolStrip: View {
    let times: [Date?]
    let codes: [Int?]
    let nights: [ClosedRange<Date>]
    let domain: ClosedRange<Date>

    private struct Item: Identifiable {
        let id: Int
        let date: Date
        let symbol: String
    }

    private var items: [Item] {
        let span = domain.upperBound.timeIntervalSince(domain.lowerBound) / 3600
        let every = span <= 30 ? 3 : (span <= 72 ? 6 : 12)
        var out: [Item] = []
        for (i, date) in times.enumerated() {
            guard let date, codes.indices.contains(i), let code = codes[i] else { continue }
            let hour = Fmt.calendar.component(.hour, from: date)
            guard hour % every == 0 else { continue }
            let night = nights.contains { $0.contains(date) }
            out.append(Item(id: i, date: date, symbol: WeatherSymbol.name(code: code, night: night)))
        }
        return out
    }

    var body: some View {
        GeometryReader { geo in
            let total = domain.upperBound.timeIntervalSince(domain.lowerBound)
            ForEach(items) { item in
                Image(systemName: item.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 16))
                    .position(x: 30 + (geo.size.width - 30) * CGFloat(item.date.timeIntervalSince(domain.lowerBound) / total), y: 14)
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 14)
        .accessibilityHidden(true)
    }
}
