import Charts
import SwiftUI

/// The past at the location: the own garden sensor and the DWD stations per day, week, month or
/// year, with records, the normal 1991–2020 and garden minus station.
struct HistoryScreen: View {
    @StateObject private var loader = Loader<HistoryResponse>()
    @AppStorage("historieZeitraum") private var unit: HistoryUnit = LaunchArgs.option.flatMap(HistoryUnit.init(rawValue:)) ?? .tage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Zeitraum", selection: $unit) {
                    ForEach(HistoryUnit.allCases) { u in
                        Text(u.label).tag(u)
                    }
                }
                .pickerStyle(.segmented)

                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    HistoryContent(data: data, unit: HistoryUnit(rawValue: data.zeitraum ?? "") ?? unit)
                        .opacity(loader.loading ? 0.6 : 1)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(
                    date: loader.date,
                    fromCache: loader.fromCache,
                    sources: "Garten: eigener Außensensor (Home Assistant) · Stationen: Deutscher Wetterdienst (KL-Tageswerte) · Normal 1991–2020: ERA5"
                )
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.load(unit.endpoint)
        }
        .task(id: unit) { await loader.loadIfNeeded(unit.endpoint, maxAge: 600) }
        .screenBackground()
        .navigationTitle("Historie")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HistoryContent: View {
    let data: HistoryResponse
    let unit: HistoryUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let garden = data.garten {
                gardenSection(garden)
            } else {
                StateMessage(kind: .empty, text: "Der Gartensensor ist am Server nicht eingerichtet.").card()
            }
            if let station = data.station {
                stationSection(station)
            }
            if let rows = data.vergleich, !rows.isEmpty {
                ComparisonCard(rows: rows, unit: unit, stationName: mainStation?.name)
            }
            ForEach(data.sourceErrors ?? [], id: \.self) { problem in
                Label("\(problem.source ?? "Quelle"): \(problem.message ?? "nicht erreichbar")", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .opacity(0.8)
            }
        }
    }

    /// The station of the temperatures (first one whose values include `tmax`).
    private var mainStation: HistoryResponse.Station? {
        data.station?.stationen?.first { $0.werte?.contains("tmax") == true }
    }

    // MARK: garden

    @ViewBuilder
    private func gardenSection(_ g: HistoryResponse.Garden) -> some View {
        if let today = g.heute {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle("Heute bisher im Garten", systemImage: "thermometer.medium", trailing: today.stunden.map { "\($0) Stunden mit Daten" })
                HStack(alignment: .top, spacing: 8) {
                    Fact(label: "Tiefstwert", value: HistoryWords.valueAt(today.tminC, today.tminZeit, exact: nil, unit: .tage))
                    Fact(label: "Höchstwert", value: HistoryWords.valueAt(today.tmaxC, today.tmaxZeit, exact: nil, unit: .tage))
                }
                GlossaryNotesView(["frost", "bodenfrost"])
            }
            .card()
        }
        if let satz = g.satz, !satz.isEmpty {
            HStack(alignment: .top, spacing: 4) {
                Text(satz).font(.callout).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                InfoButton("anomalie")
            }
            .card()
        }
        let periods = g.perioden ?? []
        if periods.isEmpty {
            StateMessage(kind: .empty, text: "Noch keine Tage vom Gartensensor.").card()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle(g.name ?? "Garten", systemImage: "leaf", trailing: g.seit.flatMap { Fmt.parse($0) }.map { "seit \(Fmt.dayMonth($0))" }, info: "tagesmittel")
                HistoryRangeChart(
                    bars: periods.compactMap { p in
                        HistoryRangeChart.Bar(id: p.key, von: p.von, low: p.tminC, high: p.tmaxC, mean: p.tmittelC, normal: p.normal, partial: p.vollstaendig == false)
                    },
                    unit: unit
                )
                HistoryLegend()
                PeriodList(count: periods.count) { limit in
                    ForEach(Array(periods.reversed().prefix(limit))) { p in
                        HistoryPeriodRow(
                            label: p.label ?? p.key,
                            badge: gardenBadge(p),
                            low: HistoryWords.valueAt(p.tminC, p.tminZeit, exact: p.tminGenau, unit: unit),
                            high: HistoryWords.valueAt(p.tmaxC, p.tmaxZeit, exact: p.tmaxGenau, unit: unit),
                            mean: p.tmittelC,
                            deviation: p.abweichungK,
                            facts: HistoryWords.kenntage(p.kenntage)
                        )
                        Divider().overlay(.white.opacity(0.15))
                    }
                }
                Text("Mittel, Kenntage und Abweichung nur aus vollständigen Tagen (ab 20 Stunden mit Daten); der laufende Tag zählt erst, wenn er vorbei ist.")
                    .font(.caption2)
                    .opacity(0.7)
                KenntageChips()
            }
            .card()
        }
        if let r = g.rekorde {
            GardenRecordsCard(records: r)
        }
    }

    private func gardenBadge(_ p: HistoryResponse.GardenPeriod) -> String? {
        if p.heute == true { return "heute bisher" }
        if unit == .tage {
            return p.vollstaendig == false ? "lückenhaft (\(p.stunden ?? 0) h)" : nil
        }
        guard let days = p.tage else { return nil }
        let complete = p.tageVollstaendig ?? 0
        return p.vollstaendig == true ? nil : "\(complete) von \(days) Tagen"
    }

    // MARK: station

    @ViewBuilder
    private func stationSection(_ s: HistoryResponse.StationBlock) -> some View {
        let periods = s.perioden ?? []
        if !periods.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle("DWD-Station", systemImage: "building.columns", trailing: s.seit.flatMap { Fmt.parse($0) }.map { "seit \(HistoryWords.date($0))" }, info: "klimanormal")
                if let station = mainStation {
                    Text(HistoryWords.station(station)).font(.footnote).opacity(0.9)
                }
                HistoryRangeChart(
                    bars: periods.compactMap { p in
                        HistoryRangeChart.Bar(id: p.key, von: p.von, low: p.tminC, high: p.tmaxC, mean: p.tmittelC, normal: p.normal, partial: false)
                    },
                    unit: unit
                )
                HistoryLegend()
                if periods.contains(where: { $0.niederschlagMm != nil }) {
                    HistoryRainChart(periods: periods, unit: unit)
                }
                PeriodList(count: periods.count) { limit in
                    ForEach(Array(periods.reversed().prefix(limit))) { p in
                        HistoryPeriodRow(
                            label: p.label ?? p.key,
                            badge: nil,
                            low: HistoryWords.valueOn(p.tminC, p.tminDatum, unit: unit),
                            high: HistoryWords.valueOn(p.tmaxC, p.tmaxDatum, unit: unit),
                            mean: p.tmittelC,
                            deviation: p.abweichungK,
                            facts: HistoryWords.stationFacts(p, unit: unit)
                        )
                        Divider().overlay(.white.opacity(0.15))
                    }
                }
                if let note = s.hinweis, !note.isEmpty {
                    Text(note).font(.caption2).opacity(0.7)
                }
                if let others = otherStations(s), !others.isEmpty {
                    Text(others).font(.caption2).opacity(0.7)
                }
            }
            .card()
        }
        if let r = s.rekorde {
            StationRecordsCard(records: r)
        }
    }

    private func otherStations(_ s: HistoryResponse.StationBlock) -> String? {
        let main = mainStation?.id
        let parts = (s.stationen ?? []).filter { $0.id != main }.map { st -> String in
            let role = (st.werte?.contains("fx_kmh") == true) ? "Wind" : "Ersatz an fehlenden Tagen"
            return "\(st.name ?? st.id) (\(role))"
        }
        guard !parts.isEmpty else { return nil }
        var text = "Außerdem: " + parts.joined(separator: ", ")
        if let n = s.ersatzTage, n > 0 { text += " · \(n) Tage mit Ersatzwerten" }
        return text
    }
}

// MARK: - pieces

/// The DWD climatological days, each opening its glossary text.
struct KenntageChips: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Kenntage nach DWD").font(.caption2.weight(.semibold)).opacity(0.75)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    InfoChip("frosttag", label: "Frosttag")
                    InfoChip("eistag", label: "Eistag")
                    InfoChip("sommertag", label: "Sommertag")
                    InfoChip("heisser_tag", label: "Heißer Tag")
                    InfoChip("tropennacht", label: "Tropennacht")
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// The newest rows of a period list; "Alle anzeigen" shows the rest.
struct PeriodList<Content: View>: View {
    let count: Int
    @ViewBuilder let content: (Int) -> Content
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content(expanded ? count : min(count, 7))
            if count > 7 {
                Button(expanded ? "Weniger anzeigen" : "Alle \(count) anzeigen") {
                    withAnimation(.snappy) { expanded.toggle() }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.plain)
                .opacity(0.85)
            }
        }
    }
}

/// One period: lowest and highest value, mean, deviation from the normal, Kenntage.
struct HistoryPeriodRow: View {
    let label: String
    let badge: String?
    let low: String
    let high: String
    let mean: Double?
    let deviation: Double?
    let facts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label).font(.subheadline.weight(.semibold))
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.white.opacity(0.16)))
                }
                Spacer(minLength: 4)
                if let mean {
                    Text("Ø " + Fmt.temp(mean, decimals: 1)).font(.subheadline.monospacedDigit())
                }
                if let deviation {
                    Text(HistoryWords.signed(deviation) + " K")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(HistoryWords.deviationColor(deviation))
                        .frame(minWidth: 50, alignment: .trailing)
                }
            }
            HStack(spacing: 12) {
                Label(low, systemImage: "arrow.down").foregroundStyle(Palette.cold)
                Label(high, systemImage: "arrow.up").foregroundStyle(Palette.warm)
            }
            .font(.footnote.monospacedDigit())
            .labelStyle(TightLabel())
            if !facts.isEmpty {
                Text(facts.joined(separator: " · ")).font(.caption).opacity(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [label]
        if let badge { parts.append(badge) }
        parts.append("Tiefstwert \(low)")
        parts.append("Höchstwert \(high)")
        if let mean { parts.append("Mittel \(Fmt.temp(mean, decimals: 1))") }
        if let deviation { parts.append("\(HistoryWords.signed(deviation)) Kelvin zum Normal") }
        return (parts + facts).joined(separator: ", ")
    }
}

struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.caption2.weight(.bold))
            configuration.title
        }
    }
}

/// Lowest to highest value per period as a bar, the normal range behind it.
struct HistoryRangeChart: View {
    struct Bar: Identifiable {
        let id: String
        let date: Date
        let low: Double
        let high: Double
        let mean: Double?
        let normalLow: Double?
        let normalHigh: Double?
        let partial: Bool

        init?(id: String, von: String?, low: Double?, high: Double?, mean: Double?, normal: HistoryResponse.Normal?, partial: Bool) {
            // noon, so that the calendar of any time zone puts the bar into the right day
            guard let start = Fmt.parse(von), let low, let high else { return nil }
            self.id = id
            date = start.addingTimeInterval(12 * 3600)
            self.low = low
            self.high = high
            self.mean = mean
            normalLow = normal?.tminC
            normalHigh = normal?.tmaxC
            self.partial = partial
        }
    }

    let bars: [Bar]
    let unit: HistoryUnit

    private var yDomain: ClosedRange<Double> {
        let values = bars.flatMap { [$0.low, $0.high, $0.normalLow, $0.normalHigh].compactMap { $0 } }
        let lo = (values.min() ?? 0) - 1
        let hi = (values.max() ?? 1) + 1
        return lo...max(hi, lo + 4)
    }

    var body: some View {
        if bars.isEmpty {
            EmptyView()
        } else {
            Chart {
                ForEach(bars) { b in
                    if let nl = b.normalLow, let nh = b.normalHigh {
                        BarMark(
                            x: .value("Zeitraum", b.date, unit: unit.calendarComponent),
                            yStart: .value("Normal Tiefstwert", nl),
                            yEnd: .value("Normal Höchstwert", nh),
                            width: .ratio(0.92)
                        )
                        .foregroundStyle(.white.opacity(0.13))
                    }
                    BarMark(
                        x: .value("Zeitraum", b.date, unit: unit.calendarComponent),
                        yStart: .value("Tiefstwert", b.low),
                        yEnd: .value("Höchstwert", max(b.high, b.low + 0.2)),
                        width: .ratio(0.5)
                    )
                    .foregroundStyle(TempBar.color(b.mean ?? (b.low + b.high) / 2).opacity(b.partial ? 0.5 : 1))
                    .cornerRadius(3)
                }
                RuleMark(y: .value("Null", 0.0))
                    .foregroundStyle(.white.opacity(yDomain.contains(0) ? 0.35 : 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .environment(\.calendar, Fmt.calendar)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: unit.calendarComponent, count: HistoryWords.axisStride(unit, bars.count))) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(HistoryWords.axisLabel(d, unit: unit)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.temp(v)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .frame(height: 170)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tiefst- und Höchstwerte je \(unit.label.dropLast())")
            .accessibilityValue(summary)
        }
    }

    private var summary: String {
        guard let lo = bars.min(by: { $0.low < $1.low }), let hi = bars.max(by: { $0.high < $1.high }) else { return "" }
        return "Tiefster Wert \(Fmt.temp(lo.low, decimals: 1)), höchster Wert \(Fmt.temp(hi.high, decimals: 1))"
    }
}

struct HistoryLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(Palette.warm).frame(width: 6, height: 12)
                Text("Tiefst bis Höchst")
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.25)).frame(width: 14, height: 12)
                Text("Normal 1991–2020")
                InfoButton("klimanormal", compact: true)
            }
        }
        .font(.caption2)
        .opacity(0.9)
    }
}

/// Precipitation per period at the station, the normal amount of the same days as a tick.
struct HistoryRainChart: View {
    let periods: [HistoryResponse.StationPeriod]
    let unit: HistoryUnit

    private struct Item: Identifiable {
        let id: String
        let date: Date
        let mm: Double
        let normal: Double?
    }

    private var items: [Item] {
        periods.compactMap { p in
            guard let start = Fmt.parse(p.von), let mm = p.niederschlagMm else { return nil }
            return Item(id: p.key, date: start.addingTimeInterval(12 * 3600), mm: mm, normal: unit == .tage ? nil : p.niederschlagNormalMm)
        }
    }

    var body: some View {
        let list = items
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Niederschlag").font(.caption.weight(.semibold))
                Spacer()
                Text(unit == .tage ? "mm je Tag" : "mm, Strich: Normal").font(.caption2).opacity(0.7)
            }
            Chart {
                ForEach(list) { item in
                    BarMark(
                        x: .value("Zeitraum", item.date, unit: unit.calendarComponent),
                        y: .value("Niederschlag", item.mm),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(Palette.rain)
                    if let normal = item.normal {
                        RectangleMark(
                            x: .value("Zeitraum", item.date, unit: unit.calendarComponent),
                            y: .value("Normal", normal),
                            width: .ratio(0.8),
                            height: .fixed(2)
                        )
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .environment(\.calendar, Fmt.calendar)
            .chartXAxis {
                AxisMarks(values: .stride(by: unit.calendarComponent, count: HistoryWords.axisStride(unit, list.count))) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(HistoryWords.axisLabel(d, unit: unit)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.number(v, decimals: 0)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .frame(height: 90)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Niederschlag je \(unit.label.dropLast())")
            .accessibilityValue("zusammen \(Fmt.precip(list.reduce(0) { $0 + $1.mm }))")
        }
    }
}

struct GardenRecordsCard: View {
    let records: HistoryResponse.GardenRecords

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Rekorde im Garten", systemImage: "trophy", trailing: records.seit.flatMap { Fmt.parse($0) }.map { "seit \(Fmt.dayMonth($0))" })
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Höchstwert", records.hoechstwert, kelvin: false, withTime: true)
                row("Tiefstwert", records.tiefstwert, kelvin: false, withTime: true)
                row("Wärmster Tag (Mittel)", records.waermsterTag, kelvin: false, withTime: false)
                row("Kältester Tag (Mittel)", records.kaeltesterTag, kelvin: false, withTime: false)
                row("Größte Spanne eines Tages", records.groessteSpanne, kelvin: true, withTime: false)
            }
            if let n = records.tage {
                Text("Aus \(n) vollständigen Tagen; der laufende Tag zählt noch nicht mit.").font(.caption2).opacity(0.7)
            }
        }
        .card()
    }

    @ViewBuilder
    private func row(_ title: String, _ r: HistoryResponse.Record?, kelvin: Bool, withTime: Bool) -> some View {
        if let r, let value = kelvin ? r.wertK : r.wertC {
            GridRow {
                Text(title).font(.footnote).opacity(0.8)
                Text(kelvin ? Fmt.value(value, 1, "K") : Fmt.temp(value, decimals: 1)).font(.footnote.weight(.semibold).monospacedDigit())
                Text(HistoryWords.recordWhen(r, withTime: withTime)).font(.caption).opacity(0.8)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct StationRecordsCard: View {
    let records: HistoryResponse.StationRecords

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Rekorde der Station", systemImage: "trophy", trailing: records.seit.flatMap { Fmt.parse($0) }.map { "seit \(HistoryWords.date($0))" })
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                row("Höchstwert", records.hoechstwertC) { Fmt.temp($0, decimals: 1) }
                row("Tiefstwert", records.tiefstwertC) { Fmt.temp($0, decimals: 1) }
                row("Tiefster Wert in 5 cm", records.bodenfrostTiefstC, info: "bodenfrost") { Fmt.temp($0, decimals: 1) }
                row("Größte Tagesmenge Niederschlag", records.niederschlagTagMm) { Fmt.precip($0) }
                row("Stärkste Böe", records.boeKmh, info: "boee") { Fmt.wind($0) }
                row("Höchste Schneedecke", records.schneeCm) { Fmt.value($0, 0, "cm") }
            }
            Text("Aus den Tageswerten, die der DWD für die letzten rund 500 Tage bereitstellt.").font(.caption2).opacity(0.7)
        }
        .card()
    }

    @ViewBuilder
    private func row(_ title: String, _ v: HistoryResponse.StationValue?, info: String? = nil, format: (Double) -> String) -> some View {
        if let v, let value = v.wert {
            let text = format(value)
            GridRow {
                HStack(spacing: 0) {
                    Text(title).font(.footnote).opacity(0.8)
                    if let info { InfoButton(info, compact: true) }
                }
                Text(text).font(.footnote.weight(.semibold).monospacedDigit())
                Text(v.datum.flatMap { Fmt.parse($0) }.map(HistoryWords.date) ?? "").font(.caption).opacity(0.8)
            }
        }
    }
}

/// Garden minus station: how much milder or colder the own garden is than the DWD station.
struct ComparisonCard: View {
    let rows: [HistoryResponse.Comparison]
    let unit: HistoryUnit
    let stationName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Garten gegen Station", systemImage: "arrow.left.arrow.right")
            Text("Garten minus \(stationName ?? "DWD-Station"): positiv heißt im Garten wärmer. Tiefstwert = meist die Nacht, Höchstwert = der Tag.")
                .font(.caption)
                .opacity(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                GridRow {
                    Text("").font(.caption2)
                    Text("Tiefstwert").font(.caption2).opacity(0.7)
                    Text("Höchstwert").font(.caption2).opacity(0.7)
                }
                ForEach(Array(rows.reversed().prefix(7))) { r in
                    GridRow {
                        Text(r.label ?? r.key).font(.footnote)
                        diff(r.tminDiffK)
                        diff(r.tmaxDiffK)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }

    private func diff(_ v: Double?) -> some View {
        Text(v.map { HistoryWords.signed($0) + " K" } ?? "–")
            .font(.footnote.weight(.semibold).monospacedDigit())
            .foregroundStyle(v.map(HistoryWords.deviationColor) ?? .white)
    }
}

// MARK: - words

enum HistoryWords {
    private static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Fmt.locale
        f.timeZone = Fmt.zone
        f.dateFormat = "d.M.yyyy"
        return f
    }()

    /// "2.7.2025", in the current year "2.7.".
    static func date(_ d: Date) -> String {
        let cal = Fmt.calendar
        return cal.component(.year, from: d) == cal.component(.year, from: Date()) ? Fmt.dayMonth(d) : fullDate.string(from: d)
    }

    /// "+2,7" / "−1,2" (real minus sign).
    static func signed(_ v: Double) -> String {
        (v > 0 ? "+" : "") + Fmt.number(v, decimals: 1)
    }

    static func deviationColor(_ v: Double) -> Color {
        if v >= 0.5 { return Palette.warm }
        if v <= -0.5 { return Palette.cold }
        return .white
    }

    /// "−0,5° um 04 Uhr" (only the hour known) / "−0,5° 04:12" / with the day for longer periods.
    static func valueAt(_ value: Double?, _ time: String?, exact: Bool?, unit: HistoryUnit) -> String {
        guard let value else { return "–" }
        var text = Fmt.temp(value, decimals: 1)
        if let t = Fmt.parse(time) {
            let clock = exact == true ? Fmt.time(t) : "gegen \(Fmt.hour(t)) Uhr"
            text += unit == .tage ? " \(clock)" : " am \(Fmt.weekdayShort(t)) \(Fmt.dayMonth(t))"
        }
        return text
    }

    /// Station value with its day for periods longer than a day.
    static func valueOn(_ value: Double?, _ day: String?, unit: HistoryUnit) -> String {
        guard let value else { return "–" }
        var text = Fmt.temp(value, decimals: 1)
        if unit != .tage, let d = Fmt.parse(day) {
            text += " am \(Fmt.dayMonth(d))"
        }
        return text
    }

    static func recordWhen(_ r: HistoryResponse.Record, withTime: Bool) -> String {
        guard let d = Fmt.parse(r.datum) else { return "" }
        var text = "\(Fmt.weekdayShort(d)) \(date(d))"
        if withTime, let t = Fmt.parse(r.zeit) {
            text += r.genau == true ? " \(Fmt.time(t))" : " gegen \(Fmt.hour(t)) Uhr"
        }
        return text
    }

    /// "1 Frosttag", "2 Sommertage" (only the ones that occurred).
    static func kenntage(_ k: HistoryResponse.Kenntage?) -> [String] {
        guard let k else { return [] }
        func word(_ n: Int?, _ one: String, _ many: String) -> String? {
            guard let n, n > 0 else { return nil }
            return "\(n) \(n == 1 ? one : many)"
        }
        return [
            word(k.eistage, "Eistag", "Eistage"),
            word(k.frosttage, "Frosttag", "Frosttage"),
            word(k.sommertage, "Sommertag", "Sommertage"),
            word(k.heisseTage, "heißer Tag", "heiße Tage"),
            word(k.tropennaechte, "Tropennacht", "Tropennächte"),
        ].compactMap { $0 }
    }

    static func stationFacts(_ p: HistoryResponse.StationPeriod, unit: HistoryUnit) -> [String] {
        var out: [String] = []
        if let mm = p.niederschlagMm {
            var text = "Niederschlag " + Fmt.precip(mm)
            if unit != .tage, let normal = p.niederschlagNormalMm, normal > 0 {
                text += " (Normal \(Fmt.precip(normal)))"
            }
            out.append(text)
        }
        if let gust = p.boeMaxKmh { out.append("Böe " + Fmt.wind(gust)) }
        if let snow = p.schneeMaxCm, snow > 0 { out.append("Schnee \(Fmt.value(snow, 0, "cm"))") }
        if let n = p.bodenfrosttage, n > 0 { out.append(unit == .tage ? "Bodenfrost" : "\(n) Tage Bodenfrost") }
        return out + kenntage(p.kenntage)
    }

    /// "Bielefeld-Deppendorf, 105 m, 19 km N: Temperatur, Niederschlag, Schnee".
    static func station(_ s: HistoryResponse.Station) -> String {
        var head = s.name ?? s.id
        var where_: [String] = []
        if let h = s.hoeheM { where_.append("\(Fmt.number(h, decimals: 0)) m") }
        if let km = s.entfernungKm { where_.append("\(Fmt.number(km, decimals: 0)) km \(s.richtung ?? "")".trimmingCharacters(in: .whitespaces)) }
        if !where_.isEmpty { head += " (\(where_.joined(separator: ", ")))" }
        let names: [String: String] = ["tmax": "Temperatur", "rr_mm": "Niederschlag", "snow_cm": "Schnee", "tg5": "Erdboden", "fx_kmh": "Wind"]
        let values = (s.werte ?? []).compactMap { names[$0] }
        return values.isEmpty ? head : "\(head): \(values.joined(separator: ", "))"
    }

    static func axisStride(_ unit: HistoryUnit, _ count: Int) -> Int {
        switch unit {
        case .tage: return count > 20 ? 7 : (count > 10 ? 2 : 1)
        case .wochen: return count > 14 ? 4 : (count > 7 ? 2 : 1)
        case .monate: return count > 12 ? 3 : (count > 6 ? 2 : 1)
        case .jahre: return 1
        }
    }

    static func axisLabel(_ d: Date, unit: HistoryUnit) -> String {
        let cal = Fmt.calendar
        switch unit {
        case .tage: return Fmt.dayMonth(d)
        case .wochen: return "KW \(cal.component(.weekOfYear, from: d))"
        case .monate:
            let month = cal.component(.month, from: d)
            let names = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
            return month == 1 ? "\(names[0]) \(cal.component(.year, from: d) % 100)" : names[month - 1]
        case .jahre: return "\(cal.component(.year, from: d))"
        }
    }
}
