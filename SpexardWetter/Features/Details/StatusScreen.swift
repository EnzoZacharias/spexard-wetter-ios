import SwiftUI

extension Endpoint {
    static let status = Endpoint(path: "/api/v1/status/uebersicht", mock: "mock_status")
}

/// State of the weather server: traffic light, data sources, request budget and jobs.
struct StatusScreen: View {
    @StateObject private var loader = Loader<StatusResponse>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    StatusContent(data: data)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Server: \(ServerSettings.current.isEmpty ? "nicht eingestellt" : "eingestellt")")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.reload()
        }
        .task { await loader.loadIfNeeded(.status, maxAge: 60) }
        .screenBackground()
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatusContent: View {
    let data: StatusResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let light = data.ampel { lightCard(light) }
            if let budget = data.budget { budgetCard(budget) }
            if let sources = data.quellen, !sources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    CardTitle("Datenquellen", systemImage: "externaldrive.connected.to.line.below")
                    ForEach(sources) { s in
                        HStack(alignment: .top, spacing: 10) {
                            Circle().fill(color(s.bewertung)).frame(width: 9, height: 9).padding(.top, 5)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(s.name ?? s.gruppe ?? "Quelle").font(.subheadline.weight(.semibold))
                                Text([s.bewertung, s.alterMin.map { "zuletzt vor \(age($0))" }, s.takt].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .card()
            }
            if let jobs = data.jobs, !jobs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    CardTitle("Geplante Abrufe", systemImage: "clock.arrow.circlepath")
                    ForEach(jobs) { job in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(job.name ?? job.id).font(.subheadline.weight(.semibold))
                            Text(jobText(job)).font(.caption).opacity(0.8)
                        }
                    }
                }
                .card()
            }
            if let server = data.server {
                Text("Server-Version \(server.version ?? "–")\(server.laufzeitH.map { ", läuft seit \(Fmt.number($0, decimals: 1)) h" } ?? "")")
                    .font(.caption)
                    .opacity(0.75)
            }
        }
    }

    private func lightCard(_ light: StatusResponse.Light) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(color(light.stufe))
                .frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2))
            VStack(alignment: .leading, spacing: 4) {
                Text(light.text ?? light.stufe ?? "–").font(.title3.weight(.semibold))
                ForEach(light.gruende ?? [], id: \.self) { reason in
                    Text(reason).font(.footnote).opacity(0.9)
                }
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private func budgetCard(_ b: StatusResponse.Budget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Abrufkontingent heute (Open-Meteo)", systemImage: "gauge.with.dots.needle.33percent")
            if let used = b.verbraucht, let cap = b.softCap, cap > 0 {
                ProgressView(value: min(used / cap, 1))
                    .tint(used / cap > 0.8 ? .orange : .green)
                Text("\(Fmt.number(used, decimals: 0)) von \(Fmt.number(cap, decimals: 0)) Einheiten\(b.anfragen.map { ", \($0) Anfragen" } ?? "")")
                    .font(.caption)
            }
            if let rejected = b.abgelehnt, rejected > 0 {
                Text("\(rejected) Anfragen abgelehnt").font(.caption).foregroundStyle(.orange)
            }
            if let pause = Fmt.parse(b.pauseBis) {
                Text("Pause bis \(Fmt.time(pause)) Uhr").font(.caption).foregroundStyle(.orange)
            }
        }
        .card()
    }

    private func jobText(_ job: StatusResponse.Job) -> String {
        var parts: [String] = []
        if let t = Fmt.parse(job.letzter) { parts.append("zuletzt \(Fmt.relativeDateTime(t, reference: Date()))") }
        if let t = Fmt.parse(job.naechster) { parts.append("nächster \(Fmt.relativeDateTime(t, reference: Date()))") }
        if let t = Fmt.parse(job.ausgeblieben) { parts.append("ausgeblieben \(Fmt.relativeDateTime(t, reference: Date()))") }
        return parts.joined(separator: " · ")
    }

    private func age(_ minutes: Double) -> String {
        minutes < 90 ? "\(Int(minutes)) min" : "\(Fmt.number(minutes / 60, decimals: 1)) h"
    }

    private func color(_ word: String?) -> Color {
        switch word?.lowercased() ?? "" {
        case "gruen", "grün", "aktuell", "ok": return .green
        case "bei bedarf": return Color(red: 0.4, green: 0.8, blue: 0.9)
        case "gelb", "alt", "veraltet", "eingeschränkt": return .yellow
        case "rot", "fehler", "ausgefallen": return .red
        default: return .gray
        }
    }
}
