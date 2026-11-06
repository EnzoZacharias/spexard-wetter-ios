import Charts
import SwiftUI

extension Endpoint {
    static let hazardMatrix = Endpoint(path: "/api/v1/gefahren/matrix", mock: "mock_gefahren_matrix")
}

/// Official warnings plus the local hazard timeline of the MOSMIX station.
struct WarningsScreen: View {
    let home: HomeModel
    @StateObject private var alerts = Loader<AlertsResponse>()
    @StateObject private var matrix = Loader<HazardMatrixResponse>()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if alerts.fromCache || matrix.fromCache { OfflineBanner(date: alerts.date ?? matrix.date) }
                    CardTitle("Amtliche Warnungen", systemImage: "exclamationmark.triangle")
                    if let value = alerts.value {
                        WarningList(block: value.warnungen, reference: home.reference)
                    } else if let error = alerts.error {
                        StateMessage(kind: .error, text: error) { await alerts.reload() }.card()
                    } else {
                        StateMessage(kind: .loading).card()
                    }

                    CardTitle("Gefahren vor Ort", systemImage: "thermometer.snowflake")
                        .padding(.top, 8)
                        .id("matrix")
                    if let value = matrix.value {
                        HazardMatrixView(matrix: value, reference: home.reference)
                    } else if let error = matrix.error {
                        StateMessage(kind: .error, text: error) { await matrix.reload() }.card()
                    } else {
                        StateMessage(kind: .loading).card()
                    }
                    StandFooter(date: matrix.date ?? alerts.date, fromCache: alerts.fromCache || matrix.fromCache, sources: "Quelle: Deutscher Wetterdienst (DWD), MOSMIX und Warnungen via Bright Sky")
                }
                .padding(16)
            }
            .refreshable {
                Haptics.armRefresh()
                async let a: Void = alerts.reload()
                async let m: Void = matrix.reload()
                _ = await (a, m)
            }
            .task {
                async let a: Void = alerts.loadIfNeeded(.alerts)
                async let m: Void = matrix.loadIfNeeded(.hazardMatrix, maxAge: 900)
                _ = await (a, m)
                if ProcessInfo.processInfo.arguments.contains("-scrollBottom") {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    proxy.scrollTo("matrix", anchor: .top)
                }
            }
        }
        .screenBackground()
        .navigationTitle("Warnungen & Gefahren")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Hourly attention levels per hazard (own colour scale, never the DWD warning colours).
struct HazardMatrixView: View {
    let matrix: HazardMatrixResponse
    let reference: Date

    struct Cell: Identifiable {
        let id: String
        let row: String
        let start: Date
        let end: Date
        let level: Int
    }

    static func color(_ level: Int) -> Color {
        let teal = Color(red: 0.25, green: 0.85, blue: 0.80)
        switch level {
        case ...0: return Color.white.opacity(0.06)
        case 1: return teal.opacity(0.35)
        case 2: return teal.opacity(0.68)
        default: return teal
        }
    }

    private var times: [Date?] { ChartTime.dates(matrix.time) }

    private var rows: [HazardMatrixResponse.Row] { matrix.zeilen.filter { $0.verfuegbar != false } }

    private var cells: [Cell] {
        var out: [Cell] = []
        for row in rows {
            let levels = row.stufen?.expanded(times.count) ?? []
            for (i, date) in times.enumerated() {
                guard let date else { continue }
                let level = levels.indices.contains(i) ? (levels[i] ?? 0) : 0
                out.append(Cell(id: "\(row.id)-\(i)", row: row.name, start: date, end: date.addingTimeInterval(3600), level: level))
            }
        }
        return out
    }

    private var domain: ClosedRange<Date>? {
        let dates = times.compactMap { $0 }
        guard let a = dates.first, let b = dates.last, b > a else { return nil }
        return a...b.addingTimeInterval(3600)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let station = matrix.station {
                Text("DWD-MOSMIX-Station \(station.name ?? station.id ?? "") (\(Fmt.value(station.entfernungKm, 0, "km")) entfernt), Lauf \(Fmt.parse(station.lauf).map { Fmt.relativeDateTime($0, reference: reference) } ?? "–"). Aufmerksamkeitsstufen des Servers, keine amtlichen Warnungen.")
                    .font(.caption)
                    .opacity(0.8)
            }
            if let domain, !rows.isEmpty {
                Chart(cells) { cell in
                    RectangleMark(
                        xStart: .value("Beginn", cell.start),
                        xEnd: .value("Ende", cell.end),
                        y: .value("Gefahr", cell.row),
                        height: .ratio(0.8)
                    )
                    .foregroundStyle(Self.color(cell.level))
                }
                .chartXScale(domain: domain)
                .chartXAxis {
                    AxisMarks(values: ChartTime.ticks(from: domain.lowerBound, to: domain.upperBound)) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.15))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(ChartTime.label(date, daily: false)).foregroundStyle(.white.opacity(0.75))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel().foregroundStyle(.white)
                    }
                }
                .frame(height: CGFloat(rows.count) * 28 + 24)
                .accessibilityLabel("Zeitleiste der Gefahren vor Ort")

                HStack(spacing: 10) {
                    ForEach(1..<4) { level in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(Self.color(level)).frame(width: 14, height: 10)
                            Text((matrix.stufenNamen ?? []).indices.contains(level) ? matrix.stufenNamen![level] : "Stufe \(level)")
                                .font(.caption2)
                        }
                    }
                }
                .opacity(0.9)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(matrix.zeilen) { row in
                    HazardRowSummary(row: row, reference: reference)
                }
            }
            if let missing = matrix.nichtVerfuegbar, !missing.isEmpty {
                Text("Nicht im MOSMIX-Lauf enthalten: " + missing.values.sorted().joined(separator: ", "))
                    .font(.caption2)
                    .opacity(0.7)
            }
        }
        .card()
    }
}

struct HazardRowSummary: View {
    let row: HazardMatrixResponse.Row
    let reference: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(HazardMatrixView.color(row.maxStufe ?? 0))
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(row.name).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(levelText).font(.caption.weight(.semibold)).opacity(0.85)
                }
                if let detail { Text(detail).font(.caption).opacity(0.8) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var levelText: String {
        if row.verfuegbar == false { return "nicht verfügbar" }
        return row.maxStufeText ?? "–"
    }

    private var detail: String? {
        if row.verfuegbar == false { return row.hinweis }
        guard (row.maxStufe ?? 0) > 0 else { return row.hinweis }
        var parts: [String] = []
        if let a = Fmt.parse(row.ersteStunde), let b = Fmt.parse(row.letzteStunde) {
            parts.append("\(Fmt.relativeDateTime(a, reference: reference)) bis \(Fmt.relativeDateTime(b, reference: reference))")
        }
        if let peak = Fmt.parse(row.spitzeStunde) {
            parts.append("am stärksten \(Fmt.relativeDateTime(peak, reference: reference))")
        }
        let words = (row.texte?.values ?? []).compactMap { $0 }
        if let common = Dictionary(grouping: words, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key {
            parts.append(common)
        }
        if let hint = row.hinweis { parts.append(hint) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
