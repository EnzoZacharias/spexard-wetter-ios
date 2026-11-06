import Charts
import SwiftUI

/// Measured values of the DWD stations around the location over 24, 48 or 72 hours.
struct MeasurementsScreen: View {
    @StateObject private var loader = Loader<MeasurementsResponse>()
    @State private var hours = Int(LaunchArgs.option ?? "") ?? 24

    private var endpoint: Endpoint {
        Endpoint(path: "/api/v1/messwerte/verlauf?stunden=\(hours)", mock: "mock_messwerte_\(hours)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Zeitraum", selection: $hours) {
                    Text("24 Stunden").tag(24)
                    Text("48 Stunden").tag(48)
                    Text("72 Stunden").tag(72)
                }
                .pickerStyle(.segmented)

                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    MeasurementsContent(data: data)
                        .opacity(loader.loading ? 0.6 : 1)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Quelle: Deutscher Wetterdienst (DWD) via Bright Sky")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.load(endpoint)
        }
        .task(id: hours) { await loader.loadIfNeeded(endpoint, maxAge: 300) }
        .screenBackground()
        .navigationTitle("Messwerte")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MeasurementsContent: View {
    let data: MeasurementsResponse

    private var times: [Date?] { ChartTime.dates(data.time) }

    private var domain: ClosedRange<Date>? {
        let d = times.compactMap { $0 }
        guard let a = d.first, let b = d.last, b > a else { return nil }
        return a...b
    }

    private var nights: [ClosedRange<Date>] {
        guard let domain else { return [] }
        return ChartTime.nights((data.sun ?? []).map { ($0.date, $0.sunrise, $0.sunset) }, within: domain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let today = data.today { TodayCard(today: today, tendency: data.pressureTendency) }
            if let domain {
                charts(domain)
            } else {
                StateMessage(kind: .empty, text: "Keine Stundenwerte im Zeitraum").card()
            }
            StationsCard(stations: data.stations)
        }
    }

    @ViewBuilder
    private func charts(_ domain: ClosedRange<Date>) -> some View {
        let temp = data.series("temperature_c")
        let dew = data.series("dew_point_c")
        if temp != nil || dew != nil {
            TimeChart(
                title: "Temperatur und Taupunkt",
                subtitle: stationNote(temp?.station, dew?.station),
                unit: "°C",
                series: [
                    ChartSeries("Temperatur", color: Palette.warm, times: times, values: temp?.values ?? []),
                    ChartSeries("Taupunkt", color: Palette.cold, dashed: true, times: times, values: dew?.values ?? []),
                ],
                domain: domain,
                nights: nights,
                minSpan: 4,
                decimals: 0
            )
        }
        let wind = data.series("wind_speed_kmh")
        let gust = data.series("wind_gusts_kmh")
        if wind != nil || gust != nil {
            TimeChart(
                title: "Wind und Böen",
                subtitle: stationNote(wind?.station, gust?.station),
                unit: "km/h",
                series: [
                    ChartSeries("Wind", color: Palette.wind, times: times, values: wind?.values ?? []),
                    ChartSeries("Böen", color: .white, style: .points, times: times, values: gust?.values ?? []),
                ],
                domain: domain,
                nights: nights,
                zeroBased: true,
                minSpan: 20
            )
        }
        if let rain = data.series("precipitation_mm") {
            TimeChart(
                title: "Niederschlag",
                subtitle: stationNote(rain.station, nil),
                unit: "mm je Stunde",
                series: [ChartSeries("Niederschlag", color: Palette.rain, style: .bars, times: times, values: rain.values)],
                domain: domain,
                nights: nights,
                zeroBased: true,
                minSpan: 1,
                decimals: 1,
                zeroText: "kein Niederschlag im Zeitraum"
            )
        }
        if let pressure = data.series("pressure_msl_hpa") {
            TimeChart(
                title: "Luftdruck (Meeresniveau)",
                subtitle: stationNote(pressure.station, nil),
                unit: "hPa",
                series: [ChartSeries("Luftdruck", color: Color(red: 0.85, green: 0.75, blue: 1.0), times: times, values: pressure.values)],
                domain: domain,
                nights: nights,
                minSpan: 6
            )
        }
        if let humidity = data.series("humidity_pct") {
            TimeChart(
                title: "Relative Luftfeuchte",
                subtitle: stationNote(humidity.station, nil),
                unit: "%",
                series: [ChartSeries("Luftfeuchte", color: Palette.rain, times: times, values: humidity.values)],
                domain: domain,
                nights: nights,
                minSpan: 20
            )
        }
        if let cloud = data.series("cloud_cover_pct") {
            TimeChart(
                title: "Bewölkung",
                subtitle: stationNote(cloud.station, nil),
                unit: "%",
                series: [ChartSeries("Bewölkung", color: Color.white.opacity(0.8), style: .area, times: times, values: cloud.values)],
                domain: domain,
                nights: nights,
                zeroBased: true,
                minSpan: 100
            )
        }
        if let visibility = data.series("visibility_m") {
            TimeChart(
                title: "Sichtweite",
                subtitle: stationNote(visibility.station, nil),
                unit: "km",
                series: [ChartSeries("Sicht", color: Palette.sun, times: times, values: visibility.values.map { $0.map { $0 / 1000 } })],
                domain: domain,
                nights: nights,
                zeroBased: true,
                minSpan: 5
            )
        }
    }

    private func stationNote(_ a: MeasurementsResponse.Station?, _ b: MeasurementsResponse.Station?) -> String? {
        let names = [a, b].compactMap { $0 }.map { station in
            "\(station.name ?? station.id) (\(Fmt.value(station.distanceKm, 0, "km")))"
        }
        let unique = names.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        return unique.isEmpty ? nil : "Station " + unique.joined(separator: ", ")
    }
}

struct TodayCard: View {
    let today: MeasurementsResponse.Today
    let tendency: MeasurementsResponse.Tendency?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Heute bisher", systemImage: "calendar.badge.clock")
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Höchstwert", value: extreme(today.tmax, unit: "°", decimals: 1))
                Fact(label: "Tiefstwert", value: extreme(today.tmin, unit: "°", decimals: 1))
                Fact(label: "Stärkste Böe", value: extreme(today.gustMax, unit: " km/h", decimals: 0))
            }
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Niederschlag", value: precipText)
                Fact(label: "Sonnenschein", value: today.sunshine?.value.map { Fmt.number($0, decimals: 1) + " h" } ?? "keine Messung")
                Fact(label: "Luftdruck", value: tendency?.text.map { t in
                    let change = tendency?.changeHpa.map { " (" + ($0 >= 0 ? "+" : "") + Fmt.number($0, decimals: 1) + " hPa in 3 h)" } ?? ""
                    return t + change
                } ?? "–")
            }
            if let normal = today.normal {
                Text("Normal für diesen Tag (\(normal.label ?? "Klima")): Max \(Fmt.temp(normal.tmaxC, decimals: 1)), Min \(Fmt.temp(normal.tminC, decimals: 1)), Niederschlag \(Fmt.precip(normal.precipMm)).")
                    .font(.caption)
                    .opacity(0.8)
            }
        }
        .card()
    }

    private func extreme(_ e: MeasurementsResponse.Extreme?, unit: String, decimals: Int) -> String {
        guard let e, let v = e.value else { return "–" }
        var text = Fmt.number(v, decimals: decimals) + unit
        if let t = Fmt.parse(e.time) { text += " um \(Fmt.time(t))" }
        if let s = e.station { text += "\n\(s)" }
        return text
    }

    private var precipText: String {
        guard let p = today.precipitation, let v = p.value else { return "–" }
        var text = Fmt.precip(v)
        if let h = p.hours, let e = p.expected, h < e { text += " (\(h) von \(e) Stunden)" }
        if let s = p.station { text += "\n\(s)" }
        return text
    }
}

struct StationsCard: View {
    let stations: [MeasurementsResponse.Station]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Stationen", systemImage: "antenna.radiowaves.left.and.right")
            ForEach(stations) { s in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.name ?? s.id).font(.subheadline.weight(.semibold))
                        Text(detail(s))
                            .font(.caption)
                            .opacity(0.8)
                    }
                    Spacer()
                    if let t = Fmt.parse(s.lastObs) {
                        Text("zuletzt \(Fmt.time(t))").font(.caption).opacity(0.8)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private func detail(_ s: MeasurementsResponse.Station) -> String {
        var parts: [String] = []
        if let km = s.distanceKm {
            let dir = s.direction.map { " " + RadarWords.directionWord($0) } ?? ""
            parts.append(Fmt.number(km, decimals: 0) + " km" + dir)
        }
        if let h = s.heightM { parts.append(Fmt.number(h, decimals: 0) + " m hoch") }
        return parts.joined(separator: " · ")
    }
}
