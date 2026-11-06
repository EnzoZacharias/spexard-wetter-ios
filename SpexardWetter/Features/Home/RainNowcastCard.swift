import Charts
import SwiftUI

/// Rain in the next two hours at the location: the server's sentence plus the DWD radar nowcast
/// in 5-minute steps (measured up to the analysis, forecast after it).
struct RainNowcastCard: View {
    let nowcast: NowcastResponse?
    let error: String?
    var surroundings: String?
    var openRadar: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Regen in 2 Stunden", systemImage: "cloud.rain", trailing: radarTime)
            if let nowcast {
                content(nowcast)
            } else if let error {
                StateMessage(kind: .error, text: error)
            } else {
                StateMessage(kind: .loading)
            }
        }
        .card()
    }

    private var radarTime: String? {
        guard let t = Fmt.parse(nowcast?.summary?.radarAnalysis) else { return nil }
        return "Radar \(Fmt.time(t))"
    }

    @ViewBuilder
    private func content(_ nc: NowcastResponse) -> some View {
        let steps = nc.steps
        let s = nc.summary
        HStack(alignment: .firstTextBaseline) {
            Text(nc.headline)
                .font(.title3.weight(.semibold))
            Spacer()
            if let openRadar {
                Button(action: openRadar) {
                    Label("Radar", systemImage: "map")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .accessibilityHint("Öffnet die Radarkarte")
            }
        }
        if let text = s?.text, !text.isEmpty {
            Text(text).font(.footnote).opacity(0.85)
        }
        if steps.isEmpty {
            StateMessage(kind: .empty, text: "Keine Radarschritte für den Standort.")
        } else {
            NowcastChart(steps: steps)
                .frame(height: 120)
        }
        HStack(alignment: .top, spacing: 8) {
            Fact(label: "Erwartete Menge", value: Fmt.precip(s?.expectedMm))
            Fact(label: "Stärkste Phase", value: peakText(s))
            Fact(label: "Umkreis 3 km", value: nearText(s))
        }
        if let surroundings, !surroundings.isEmpty {
            Label {
                Text(surroundings).font(.footnote).lineLimit(3)
            } icon: {
                Image(systemName: "scope")
            }
            .opacity(0.9)
            .accessibilityLabel("Radar im Umkreis: \(surroundings)")
        }
    }

    private func peakText(_ s: NowcastResponse.Summary?) -> String {
        guard let peak = s?.peakMmH, peak > 0 else { return "trocken" }
        let word = s?.peakIntensity.map { ", \($0)" } ?? ""
        return Fmt.rate(peak) + word
    }

    private func nearText(_ s: NowcastResponse.Summary?) -> String {
        if s?.rainWithin3kmNow == true { return "Regen gerade" }
        if s?.rainNearbyInNowcast == true { return "im Nowcast" }
        return "trocken"
    }
}

/// Bars of the rain rate per 5-minute interval; the forecast part sits on a lighter band.
struct NowcastChart: View {
    let steps: [NowcastResponse.Step]

    private var maxRate: Double { steps.compactMap(\.mmh).max() ?? 0 }
    private var dry: Bool { steps.allSatisfy { ($0.mmh ?? 0) < 0.1 } }
    private var yTop: Double { max(1, (maxRate * 1.15).rounded(.up)) }
    private var forecastStart: Date? { steps.first(where: \.forecast).map { $0.end.addingTimeInterval(-300) } }
    private var lastEnd: Date? { steps.last?.end }
    private var firstStart: Date? { steps.first.map { $0.end.addingTimeInterval(-300) } }

    var body: some View {
        Chart {
            if let from = forecastStart, let end = lastEnd {
                RectangleMark(
                    xStart: .value("Prognose ab", from),
                    xEnd: .value("Ende", end),
                    yStart: .value("unten", 0.0),
                    yEnd: .value("oben", yTop)
                )
                .foregroundStyle(.white.opacity(0.08))
                .annotation(position: .overlay, alignment: .topLeading) {
                    Text("Prognose")
                        .font(.caption2)
                        .opacity(0.7)
                        .padding(4)
                }
            }
            ForEach(steps) { step in
                if let v = step.mmh, v > 0 {
                    RectangleMark(
                        xStart: .value("Beginn", step.end.addingTimeInterval(-290)),
                        xEnd: .value("Ende", step.end.addingTimeInterval(-10)),
                        yStart: .value("null", 0.0),
                        yEnd: .value("mm/h", v)
                    )
                    .foregroundStyle(step.forecast ? Palette.rain.opacity(0.75) : Palette.rain)
                }
            }
        }
        .chartYScale(domain: 0...yTop)
        .chartXScale(domain: (firstStart ?? Date())...(lastEnd ?? Date()))
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 30)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.15))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(Fmt.time(date)).foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, yTop / 2, yTop]) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.number(v, decimals: yTop < 4 ? 1 : 0)).foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .overlay {
            if dry {
                Text("kein Niederschlag")
                    .font(.footnote.weight(.semibold))
                    .opacity(0.8)
            }
        }
        .overlay(alignment: .topTrailing) {
            Text("mm/h").font(.caption2).opacity(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Niederschlag am Standort in 5-Minuten-Schritten")
        .accessibilityValue(dry ? "Kein Niederschlag im gesamten Zeitraum" : "Höchste Rate \(Fmt.rate(maxRate))")
    }
}
