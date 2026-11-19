import SwiftUI

/// Mehr → Umwelt & Himmel (`/api/v1/umwelt`): sun and moon, air quality, pollen and UV index, each
/// with its source and the server's notes at conspicuous values.
struct EnvironmentScreen: View {
    @StateObject private var loader = Loader<EnvironmentResponse>()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
            }
            .refreshable {
                Haptics.armRefresh()
                await loader.load(.environment)
            }
            .task {
                await loader.loadIfNeeded(.environment, maxAge: 600)
                // screenshots: `-scrollBottom` starts at the air quality (`-option pollen`: at the pollen)
                if ProcessInfo.processInfo.arguments.contains("-scrollBottom") {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    proxy.scrollTo(LaunchArgs.option == "pollen" ? "pollen" : "luft", anchor: .top)
                }
            }
        }
        .screenBackground()
        .navigationTitle("Umwelt & Himmel")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 12) {
                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    EnvironmentContent(data: data)
                        .opacity(loader.loading ? 0.6 : 1)
                } else if let error = loader.error {
                    VStack(spacing: 6) {
                        StateMessage(kind: .error, text: error) { await loader.reload() }
                        Text("Pollen, UV, Luftqualität sowie Sonne und Mond brauchen einen aktuellen Wetterserver.")
                            .font(.caption)
                            .opacity(0.75)
                            .multilineTextAlignment(.center)
                    }
                    .card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(
                    date: loader.date,
                    fromCache: loader.fromCache,
                    sources: "Pollen und UV: Deutscher Wetterdienst · Luft: Umweltbundesamt · Sonne und Mond: vom Wetterserver berechnet"
                )
            }
            .padding(16)
    }
}

struct EnvironmentContent: View {
    let data: EnvironmentResponse

    /// "Now" of the answer: the server's time in the screenshots, else the clock.
    private var reference: Date {
        APIClient.isMock ? (Fmt.parse(data.generatedAt) ?? Date()) : Date()
    }

    private func notes(_ block: String) -> [GlossaryNote] {
        (data.hinweise ?? []).filter { ($0.bezug ?? "").hasPrefix("umwelt.\(block)") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sun = data.astro?.sonne {
                SunCard(sun: sun, day: data.astro?.datum, reference: reference)
            }
            if let moon = data.astro?.mond {
                MoonCard(moon: moon)
            }
            Group {
                if let air = data.luft {
                    AirCard(air: air, notes: notes("luft"))
                } else {
                    missing("Luftqualität", "Das Umweltbundesamt hat gerade keine Messwerte geliefert.")
                }
            }
            .id("luft")
            if let air = data.luft {
                AirHistoryChart(air: air)
            }
            if let pollen = data.pollen {
                PollenCard(pollen: pollen, notes: notes("pollen")).id("pollen")
            } else {
                missing("Pollenflug", "Der Pollenflug-Gefahrenindex des DWD fehlt gerade.")
            }
            if let uv = data.uv {
                UVCard(uv: uv, notes: notes("uv"))
            } else {
                missing("UV-Index", "Der UV-Gefahrenindex des DWD fehlt gerade.")
            }
            ForEach(data.sourceErrors ?? [], id: \.self) { problem in
                Label("\(problem.source ?? "Quelle"): \(problem.message ?? "nicht erreichbar")", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .opacity(0.8)
            }
        }
    }

    private func missing(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(text).font(.footnote).opacity(0.8)
        }
        .card()
    }
}

// MARK: - sun

struct SunCard: View {
    let sun: EnvironmentResponse.Sun
    let day: String?
    let reference: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Sonne", systemImage: "sun.max.fill", trailing: Fmt.parse(day).map { Fmt.longDate($0) }, info: "tageslaenge")
            if let rise = Fmt.parse(sun.aufgang), let set = Fmt.parse(sun.untergang), set > rise {
                SunArc(rise: rise, set: set, now: reference, noon: Fmt.parse(sun.mittag), elevation: sun.hoechststandGrad)
                    .frame(height: 96)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sonnenaufgang \(Fmt.time(rise)) Uhr, Sonnenuntergang \(Fmt.time(set)) Uhr")
            }
            HStack(alignment: .top, spacing: 8) {
                Fact(label: "Tageslänge", value: EnvironmentScale.duration(sun.tageslaengeMin) + (EnvironmentScale.change(sun.aenderungMin).map { "\n\($0)" } ?? ""))
                Fact(label: "Dämmerung (bürgerlich)", value: "\(Fmt.time(Fmt.parse(sun.daemmerungBeginn))) – \(Fmt.time(Fmt.parse(sun.daemmerungEnde)))", info: "daemmerung")
                Fact(label: "Höchststand", value: (sun.hoechststandGrad.map { Fmt.number($0, decimals: 1) + "°" } ?? "–") + " um " + Fmt.time(Fmt.parse(sun.mittag)), info: "sonnenhoehe")
            }
            if let days = sun.tage, days.count > 1 {
                Divider().overlay(.white.opacity(0.2))
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
                    GridRow {
                        Text("").font(.caption2)
                        Text("Aufgang").font(.caption2).opacity(0.7)
                        Text("Untergang").font(.caption2).opacity(0.7)
                        Text("Tageslänge").font(.caption2).opacity(0.7)
                    }
                    ForEach(days) { d in
                        GridRow {
                            Text(Fmt.parse(d.datum).map { "\(Fmt.weekdayShort($0)) \(Fmt.dayMonth($0))" } ?? d.datum)
                            Text(Fmt.time(Fmt.parse(d.aufgang)))
                            Text(Fmt.time(Fmt.parse(d.untergang)))
                            Text(EnvironmentScale.duration(d.tageslaengeMin))
                        }
                        .font(.footnote.monospacedDigit())
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .card()
    }
}

/// The sun's path over the day: rise on the left, set on the right, the sun at the time of the
/// answer (below the horizon line before sunrise and after sunset).
struct SunArc: View {
    let rise: Date
    let set: Date
    let now: Date
    let noon: Date?
    let elevation: Double?

    private var fraction: Double {
        now.timeIntervalSince(rise) / set.timeIntervalSince(rise)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let base = geo.size.height - 22
            let height = base - 16
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: base))
                    p.addLine(to: CGPoint(x: w, y: base))
                }
                .stroke(.white.opacity(0.35), lineWidth: 1)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: base))
                    p.addQuadCurve(to: CGPoint(x: w, y: base), control: CGPoint(x: w / 2, y: base - 2 * height))
                }
                .stroke(Palette.sun.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                let f = CGFloat(min(max(fraction, 0), 1))
                let up = fraction > 0 && fraction < 1
                Circle()
                    .fill(up ? Palette.sun : Color.white.opacity(0.35))
                    .frame(width: 16, height: 16)
                    .shadow(color: up ? Palette.sun.opacity(0.8) : .clear, radius: 6)
                    .position(x: w * f, y: up ? base - 4 * f * (1 - f) * height : base)
                Text(Fmt.time(rise)).font(.caption.monospacedDigit()).position(x: 22, y: base + 12)
                Text(Fmt.time(set)).font(.caption.monospacedDigit()).position(x: w - 22, y: base + 12)
                if let noon {
                    Text(Fmt.time(noon) + (elevation.map { " · " + Fmt.number($0, decimals: 0) + "°" } ?? ""))
                        .font(.caption2.monospacedDigit())
                        .opacity(0.75)
                        .position(x: w / 2, y: base - height - 10)
                }
            }
        }
    }
}

// MARK: - moon

struct MoonCard: View {
    let moon: EnvironmentResponse.Moon

    private struct Event: Identifiable {
        /// "Aufgang" or "Untergang".
        let id: String
        let date: Date
    }

    /// Rise and set in the order they happen on the day.
    private var events: [Event] {
        var out: [Event] = []
        if let rise = Fmt.parse(moon.aufgang) { out.append(Event(id: "Aufgang", date: rise)) }
        if let set = Fmt.parse(moon.untergang) { out.append(Event(id: "Untergang", date: set)) }
        return out.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Mond", systemImage: "moon.stars.fill", info: "mondphase")
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: EnvironmentScale.moonSymbol(moon.phase, waxing: moon.zunehmend))
                    .font(.system(size: 46))
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(moon.phase ?? "–").font(.title3.weight(.semibold))
                    if let pct = moon.beleuchtungPct {
                        Text("\(Int(pct.rounded())) % beleuchtet" + (moon.zunehmend == true ? ", zunehmend" : moon.zunehmend == false ? ", abnehmend" : ""))
                            .font(.footnote)
                    }
                    if let age = moon.alterTage {
                        Text("\(Fmt.number(age, decimals: 1)) Tage nach Neumond").font(.caption).opacity(0.8)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            if !events.isEmpty {
                HStack(spacing: 8) {
                    ForEach(events) { event in
                        Fact(label: event.id, value: Fmt.time(event.date) + " Uhr")
                    }
                }
            }
            if let phases = moon.naechstePhasen, !phases.isEmpty {
                Divider().overlay(.white.opacity(0.2))
                ForEach(phases, id: \.self) { p in
                    HStack {
                        Image(systemName: EnvironmentScale.moonSymbol(p.phase, waxing: nil))
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        Text(p.phase ?? "–").font(.footnote.weight(.semibold))
                        Spacer()
                        Text(Fmt.parse(p.zeit).map { "\(Fmt.weekdayShort($0)) \(Fmt.dayMonth($0)) \(Fmt.time($0)) Uhr" } ?? "–")
                            .font(.footnote.monospacedDigit())
                            .opacity(0.85)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }
}

// MARK: - air

struct AirCard: View {
    let air: EnvironmentResponse.Air
    let notes: [GlossaryNote]

    private static func info(_ id: String) -> String? {
        switch id {
        case "pm10", "pm25": return "feinstaub"
        case "o3": return "ozon"
        case "no2": return "stickstoffdioxid"
        default: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Luftqualität", systemImage: "aqi.medium", trailing: Fmt.parse(air.stand).map { "\(Fmt.time($0)) Uhr" }, info: "luftqualitaet")
            HStack(alignment: .center, spacing: 12) {
                Text(air.text ?? "–")
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(EnvironmentScale.airColor(air.index).opacity(0.85)))
                    .foregroundStyle(air.index == 2 ? Color.black.opacity(0.8) : .white)
                VStack(alignment: .leading, spacing: 1) {
                    Text("UBA-Luftqualitätsindex").font(.caption.weight(.semibold))
                    Text(stationText).font(.caption).opacity(0.8)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            ForEach(air.werte ?? []) { v in
                HStack(spacing: 8) {
                    Circle().fill(EnvironmentScale.airColor(v.index)).frame(width: 9, height: 9).accessibilityHidden(true)
                    Text(v.symbol ?? v.id).font(.footnote.weight(.semibold)).frame(width: 52, alignment: .leading)
                    Text(v.name ?? "").font(.caption).opacity(0.8).lineLimit(1)
                    if let info = Self.info(v.id) { InfoButton(info, compact: true) }
                    Spacer(minLength: 4)
                    Text(Fmt.value(v.wert, 0, v.einheit ?? "")).font(.footnote.monospacedDigit())
                    Text(v.text ?? "").font(.caption2).opacity(0.75).frame(width: 66, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
            if air.unvollstaendig == true {
                Text("Die Station misst nicht alle Schadstoffe des Index; er gilt für die gemessenen.")
                    .font(.caption2)
                    .opacity(0.7)
            }
            ForEach(notes, id: \.self) { note in
                NoteCallout(note: note)
            }
        }
        .card()
    }

    private var stationText: String {
        var parts = ["Station " + (air.station ?? "–")]
        if let km = air.entfernungKm { parts.append("\(Fmt.number(km, decimals: 0)) km") }
        return parts.joined(separator: ", ")
    }
}

/// The pollutants of the last 24 hours at the UBA station.
struct AirHistoryChart: View {
    let air: EnvironmentResponse.Air

    var body: some View {
        let times = ChartTime.dates(air.verlauf?.zeit ?? [])
        let dates = times.compactMap { $0 }
        if let h = air.verlauf, let first = dates.first, let last = dates.last, last > first {
            TimeChart(
                title: "Die letzten 24 Stunden",
                unit: "µg/m³",
                series: [
                    ChartSeries("PM₁₀", color: Color(red: 0.80, green: 0.70, blue: 0.55), times: times, values: h.pm10 ?? []),
                    ChartSeries("PM₂,₅", color: Color(red: 1.0, green: 0.62, blue: 0.35), dashed: true, times: times, values: h.pm25 ?? []),
                    ChartSeries("NO₂", color: Color(red: 0.62, green: 0.86, blue: 1.0), times: times, values: h.no2 ?? []),
                    ChartSeries("O₃", color: Color(red: 0.70, green: 0.95, blue: 0.80), times: times, values: h.o3 ?? []),
                ].filter { !$0.isEmpty },
                domain: first...last,
                zeroBased: true,
                minSpan: 10,
                info: "feinstaub"
            )
        }
    }
}

// MARK: - pollen

struct PollenCard: View {
    let pollen: EnvironmentResponse.Pollen
    let notes: [GlossaryNote]

    private var types: [EnvironmentResponse.PollenType] { pollen.arten ?? [] }
    private var active: [EnvironmentResponse.PollenType] { types.filter { ($0.maxLevel ?? 0) > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Pollenflug", systemImage: "leaf.fill", trailing: "Ostwestfalen", info: "pollenflug")
            if types.isEmpty {
                Text("Der DWD liefert gerade keine Pollenvorhersage.").font(.footnote)
            } else if active.isEmpty {
                Label("Keine Belastung bis übermorgen", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                Text("Keine der \(types.count) Arten fliegt: " + types.compactMap(\.name).joined(separator: ", ") + ".")
                    .font(.caption)
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        Text("").font(.caption2)
                        ForEach(dayLabels, id: \.self) { label in
                            Text(label).font(.caption2).opacity(0.7).gridColumnAlignment(.center)
                        }
                    }
                    ForEach(active) { type in
                        GridRow {
                            Text(type.name ?? type.id).font(.footnote.weight(.semibold))
                            ForEach(0..<3, id: \.self) { i in
                                levelChip(type.days[i])
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibility(type))
                    }
                }
                let quiet = types.filter { ($0.maxLevel ?? 0) <= 0 }.compactMap(\.name)
                if !quiet.isEmpty {
                    Text("Ohne Belastung: " + quiet.joined(separator: ", ")).font(.caption2).opacity(0.7)
                }
                legend
            }
            ForEach(notes, id: \.self) { note in
                NoteCallout(note: note)
            }
            Text(issueText).font(.caption2).opacity(0.7)
        }
        .card()
    }

    /// "Heute", "Morgen" and the weekday after.
    private var dayLabels: [String] {
        let third = types.lazy.compactMap { Fmt.parse($0.uebermorgen?.datum) }.first.map { Fmt.weekdayShort($0) }
        return ["Heute", "Morgen", third ?? "Übermorgen"]
    }

    private func levelChip(_ day: EnvironmentResponse.PollenDay?) -> some View {
        Text(day?.stufe.map { $0.replacingOccurrences(of: "-", with: "–") } ?? "–")
            .font(.caption.weight(.bold).monospacedDigit())
            .frame(minWidth: 44)
            .padding(.vertical, 3)
            .background(Capsule().fill(EnvironmentScale.pollenColor(day?.wert)))
            .foregroundStyle((day?.wert ?? 0) >= 0.75 && (day?.wert ?? 0) < 2.25 ? Color.black.opacity(0.8) : .white)
            .gridColumnAlignment(.center)
    }

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { level in
                HStack(spacing: 3) {
                    Circle().fill(EnvironmentScale.pollenColor(Double(level))).frame(width: 8, height: 8)
                    Text(["0 keine", "1 gering", "2 mittel", "3 hoch"][level])
                }
            }
        }
        .font(.caption2)
        .opacity(0.85)
        .accessibilityHidden(true)
    }

    private func accessibility(_ type: EnvironmentResponse.PollenType) -> String {
        let names = ["heute", "morgen", "übermorgen"]
        let parts = type.days.enumerated().map { i, d in "\(names[i]) \(d?.text ?? "keine Angabe")" }
        return "\(type.name ?? type.id): " + parts.joined(separator: ", ")
    }

    private var issueText: String {
        var text = "Pollenflug-Gefahrenindex des DWD" + (pollen.region.map { ", \($0)" } ?? "")
        if let issued = Fmt.parse(pollen.ausgabe) { text += " · Ausgabe \(Fmt.weekdayShort(issued)) \(Fmt.time(issued)) Uhr" }
        return text
    }
}

// MARK: - UV

struct UVCard: View {
    let uv: EnvironmentResponse.UV
    let notes: [GlossaryNote]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("UV-Index", systemImage: "sun.max.trianglebadge.exclamationmark", info: "uv_index")
            HStack(spacing: 8) {
                column("Heute", uv.heute)
                column("Morgen", uv.morgen)
                column(Fmt.parse(uv.uebermorgen?.datum).map { Fmt.weekdayShort($0) } ?? "Übermorgen", uv.uebermorgen)
            }
            ForEach(notes, id: \.self) { note in
                NoteCallout(note: note)
            }
            Text(sourceText).font(.caption2).opacity(0.7)
        }
        .card()
    }

    private func column(_ label: String, _ day: EnvironmentResponse.UVDay?) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).opacity(0.8)
            Text(day?.uvIndex.map { Fmt.number($0, decimals: 0) } ?? "–")
                .font(.title2.weight(.bold).monospacedDigit())
                .frame(width: 46, height: 46)
                .background(Circle().fill(EnvironmentScale.uvColor(day?.uvIndex)))
                .foregroundStyle((day?.uvIndex ?? 0) >= 2.5 && (day?.uvIndex ?? 0) < 7.5 ? Color.black.opacity(0.8) : .white)
            Text(day?.stufe ?? "–").font(.caption2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var sourceText: String {
        var text = "UV-Gefahrenindex des DWD"
        if let place = uv.ort {
            text += " für \(place)"
            if let km = uv.entfernungKm { text += " (rund \(Fmt.number(km, decimals: 0)) km)" }
        }
        if let issued = Fmt.parse(uv.ausgabe) { text += " · Ausgabe \(Fmt.time(issued)) Uhr" }
        return text
    }
}

// MARK: - home

/// Start screen: air, pollen, UV and moon of today in one card; a tap opens Umwelt & Himmel.
/// Hidden while the server has no `/api/v1/umwelt`.
struct EnvironmentHomeCard: View {
    let data: EnvironmentResponse
    let open: () -> Void

    private struct Tile: Identifiable {
        let id: String
        let icon: String
        let title: String
        let value: String
        let note: String?
        let color: Color?
    }

    private var tiles: [Tile] {
        var out: [Tile] = []
        if let air = data.luft, let text = air.text {
            out.append(Tile(id: "luft", icon: "aqi.medium", title: "Luft", value: text, note: air.station.map { "UBA \($0)" }, color: EnvironmentScale.airColor(air.index)))
        }
        if let types = data.pollen?.arten, !types.isEmpty {
            let today = types.compactMap { t -> (String, EnvironmentResponse.PollenDay)? in
                guard let d = t.heute, (d.wert ?? 0) > 0 else { return nil }
                return (t.name ?? t.id, d)
            }
            if let top = today.max(by: { ($0.1.wert ?? 0) < ($1.1.wert ?? 0) }) {
                let more = today.count > 1 ? " +\(today.count - 1)" : ""
                out.append(Tile(id: "pollen", icon: "leaf.fill", title: "Pollen heute", value: "\(top.0) \(top.1.stufe?.replacingOccurrences(of: "-", with: "–") ?? "")\(more)", note: top.1.text, color: EnvironmentScale.pollenColor(top.1.wert)))
            } else {
                out.append(Tile(id: "pollen", icon: "leaf.fill", title: "Pollen heute", value: "keine", note: "alle \(types.count) Arten", color: nil))
            }
        }
        if let day = data.uv?.heute, let index = day.uvIndex {
            out.append(Tile(id: "uv", icon: "sun.max.trianglebadge.exclamationmark", title: "UV-Index heute", value: Fmt.number(index, decimals: 0) + (day.stufe.map { " · \($0)" } ?? ""), note: data.uv?.ort.map { "DWD \($0)" }, color: EnvironmentScale.uvColor(index)))
        }
        if let moon = data.astro?.mond {
            let pct = moon.beleuchtungPct.map { "\(Int($0.rounded())) %" } ?? ""
            out.append(Tile(id: "mond", icon: EnvironmentScale.moonSymbol(moon.phase, waxing: moon.zunehmend), title: "Mond", value: pct, note: moon.phase, color: nil))
        }
        return out
    }

    var body: some View {
        let items = tiles
        if !items.isEmpty {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        CardTitle("Umwelt & Himmel", systemImage: "aqi.medium")
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).opacity(0.6)
                    }
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10, alignment: .topLeading), GridItem(.flexible(), spacing: 10, alignment: .topLeading)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(items) { tile in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: tile.icon)
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.callout)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(tile.title).font(.caption2).opacity(0.75)
                                    HStack(spacing: 5) {
                                        if let color = tile.color {
                                            Circle().fill(color).frame(width: 9, height: 9)
                                        }
                                        Text(tile.value).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                    if let note = tile.note {
                                        Text(note).font(.caption2).opacity(0.65).lineLimit(2)
                                    }
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .card()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet Umwelt und Himmel")
        }
    }
}
