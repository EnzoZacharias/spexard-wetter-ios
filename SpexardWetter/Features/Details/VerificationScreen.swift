import Charts
import SwiftUI

/// How well the models did at the location over the last 7, 30 or 90 days.
struct VerificationScreen: View {
    @StateObject private var loader = Loader<VerificationResponse>()
    @AppStorage("modellgueteTage") private var days = Int(LaunchArgs.option ?? "") ?? 30

    private var endpoint: Endpoint {
        Endpoint(path: "/api/v1/verifikation/auswertung?tage=\(days)", mock: "mock_verifikation_\(days)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Zeitraum", selection: $days) {
                    Text("7 Tage").tag(7)
                    Text("30 Tage").tag(30)
                    Text("90 Tage").tag(90)
                }
                .pickerStyle(.segmented)

                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    VerificationContent(data: data)
                        .opacity(loader.loading ? 0.6 : 1)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Vorhersagen: Open-Meteo.com (CC BY 4.0), Messungen: DWD")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.load(endpoint)
        }
        .task(id: days) { await loader.loadIfNeeded(endpoint, maxAge: 3600) }
        .screenBackground()
        .navigationTitle("Modellgüte")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VerificationContent: View {
    let data: VerificationResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if data.hatDaten == false {
                StateMessage(kind: .empty, text: data.hinweis ?? "Noch keine Auswertung für diesen Zeitraum.").card()
            }
            if let lines = data.aussagen, !lines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        CardTitle(periodTitle, systemImage: "checkmark.seal", info: "mae")
                        InfoButton("bias")
                    }
                    ForEach(lines, id: \.self) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("•")
                            Text(line).font(.callout)
                        }
                    }
                }
                .card()
            }
            ForEach(data.variablen ?? []) { variable in
                VariableCard(variable: variable)
            }
        }
    }

    private var periodTitle: String {
        guard let a = Fmt.parse(data.zeitraum?.von), let b = Fmt.parse(data.zeitraum?.bis) else { return "Auswertung" }
        return "\(Fmt.dayMonth(a)) bis \(Fmt.dayMonth(b))"
    }
}

/// Ranking of the models for one variable: mean absolute error as bars, bias in words.
struct VariableCard: View {
    let variable: VerificationResponse.Variable

    var body: some View {
        let ranks = (variable.rangliste ?? []).filter { $0.mae != nil }
        let unit = variable.fehlerEinheit ?? ""
        VStack(alignment: .leading, spacing: 8) {
            Text(variable.label ?? variable.key).font(.headline)
            if let text = variable.aussage { Text(text).font(.footnote).opacity(0.9) }
            if !ranks.isEmpty {
                Chart(ranks) { r in
                    BarMark(x: .value("Fehler", r.mae ?? 0), y: .value("Modell", r.name ?? ModelNames.short(r.model)))
                        .foregroundStyle(Palette.model(r.model).opacity(r.lowN == true ? 0.5 : 1))
                        .annotation(position: .trailing, spacing: 4) {
                            Text(Fmt.number(r.mae ?? 0, decimals: 1) + " " + unit)
                                .font(.caption2.monospacedDigit())
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(.white)
                    }
                }
                .frame(height: CGFloat(ranks.count) * 26 + 8)
                .accessibilityLabel("Mittlerer Fehler je Modell")
                ForEach(ranks) { r in
                    if let bias = r.biasText {
                        Text("\(r.name ?? ModelNames.short(r.model)): \(bias)\(r.lowN == true ? " (wenige Tage)" : "")")
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
            }
            ForEach(variable.auffaellig ?? [], id: \.self) { line in
                Label(line, systemImage: "exclamationmark.circle").font(.caption)
            }
            if let station = variable.station {
                Text("Gemessen: \(station)").font(.caption2).opacity(0.7)
            }
            Text("Balken: mittlerer absoluter Fehler (kleiner ist besser)").font(.caption2).opacity(0.6)
        }
        .card()
    }
}
