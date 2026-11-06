import Charts
import SwiftUI

extension Endpoint {
    static let largeScale = Endpoint(path: "/api/v1/tools/large_scale", mock: "mock_large_scale")
    static let gwlCatalog = Endpoint(path: "/api/v1/grosswetterlage/katalog", mock: "mock_grosswetterlage_katalog")
}

/// Großwetterlage, ensemble regimes, polar vortex and the AO/NAO indices.
struct LargeScaleScreen: View {
    @StateObject private var loader = Loader<LargeScaleResponse>()
    @StateObject private var catalog = Loader<GwlCatalogResponse>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if loader.fromCache { OfflineBanner(date: loader.date) }
                if let data = loader.value {
                    LargeScaleContent(data: data, catalog: catalog.value)
                } else if let error = loader.error {
                    StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Quellen: DWD (Synoptische Übersichten), NOAA CPC (AO/NAO), Open-Meteo.com (CC BY 4.0)")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await loader.reload()
        }
        .task {
            async let a: Void = loader.loadIfNeeded(.largeScale, maxAge: 1800)
            async let b: Void = catalog.loadIfNeeded(.gwlCatalog, maxAge: 86_400)
            _ = await (a, b)
        }
        .screenBackground()
        .navigationTitle("Großwetterlage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LargeScaleContent: View {
    let data: LargeScaleResponse
    let catalog: GwlCatalogResponse?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let gwl = data.grosswetterlage { gwlCard(gwl) }
            if let codes = catalog?.ensemble?.codes, !codes.isEmpty { ensembleCard(codes) }
            if let regime = data.regime { regimeCard(regime) }
            if let vortex = data.polarwirbel { VortexCard(vortex: vortex) }
            HStack(alignment: .top, spacing: 12) {
                if let ao = data.ao { OscillationCard(index: ao, short: "AO") }
                if let nao = data.nao { OscillationCard(index: nao, short: "NAO") }
            }
            if let hint = catalog?.quelleKatalog {
                Text("Katalog: \(hint)").font(.caption2).opacity(0.7)
            }
        }
    }

    private func typeInfo(_ typ: String?) -> GwlCatalogResponse.TypeInfo? {
        guard let typ else { return nil }
        return catalog?.typen?.first { $0.grosswettertyp == typ }
    }

    /// Winter half-year October to March.
    private var winter: Bool {
        let month = Fmt.calendar.component(.month, from: Date())
        return month >= 10 || month <= 3
    }

    private func gwlCard(_ g: LargeScaleResponse.Gwl) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Großwetterlage (DWD)", systemImage: "globe.europe.africa.fill")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(g.code ?? "–")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text(g.name ?? "").font(.title3.weight(.semibold))
            }
            HStack(spacing: 8) {
                if let typ = g.grosswettertyp { chip("Typ \(typ)") }
                if let form = g.zirkulationsform { chip(form) }
                if let cyc = g.zyklonal { chip(cyc ? "zyklonal (Tief)" : "antizyklonal (Hoch)") }
            }
            if let extra = g.zusatz { Text("Zusatz des DWD: \(extra)").font(.callout) }
            if let info = typeInfo(g.grosswettertyp), let text = winter ? info.winterhalbjahr : info.sommerhalbjahr {
                Text("Typisch im \(winter ? "Winter" : "Sommer")halbjahr: \(text)").font(.footnote).opacity(0.9)
            }
            if let form = g.zirkulationsform, let text = catalog?.zirkulationsformen?[form] {
                Text(text).font(.footnote).opacity(0.85)
            }
            if let report = g.bericht {
                Text("\(report)\(Fmt.parse(g.ausgegebenLokal).map { ", " + Fmt.relativeDateTime($0, reference: Date()) } ?? "")")
                    .font(.caption2)
                    .opacity(0.7)
            }
        }
        .card()
    }

    private func ensembleCard(_ codes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Lagen im Ensemble (Mittelfrist)", systemImage: "square.stack.3d.down.right")
            ForEach(codes, id: \.self) { code in
                let entry = catalog?.katalog?.first { $0.code == code }
                HStack(alignment: .firstTextBaseline) {
                    Text(code).font(.headline.monospaced()).frame(width: 64, alignment: .leading)
                    Text(entry?.name ?? "").font(.subheadline)
                }
            }
        }
        .card()
    }

    private func regimeCard(_ r: LargeScaleResponse.Regime) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Wetterregime (DWD Mittelfrist)", systemImage: "arrow.triangle.branch")
            if let headline = r.schlagzeile {
                Text(headline).font(.system(.body, design: .serif).weight(.semibold))
            }
            ForEach(r.genannteRegime ?? [], id: \.self) { name in
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.subheadline.weight(.semibold))
                    if let meaning = r.bedeutung?[name] {
                        Text(meaning).font(.footnote).opacity(0.85)
                    }
                }
            }
            if let text = r.grosswetterlageEnsemble { Text(text).font(.footnote) }
            if let text = r.clusteranalyse { Text(text).font(.footnote).opacity(0.85) }
            ForEach(Array((r.konsistenz ?? []).enumerated()), id: \.offset) { _, k in
                Text("\(k.zeitraum ?? ""): \(k.aussage ?? "")").font(.caption).opacity(0.8)
            }
            if let report = r.bericht {
                Text(report).font(.caption2).opacity(0.7)
            }
        }
        .card()
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.16)))
    }
}

/// Zonal wind at 60° N in 10 hPa: west = intact vortex, east = reversal.
struct VortexCard: View {
    let vortex: LargeScaleResponse.Vortex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle("Polarwirbel", systemImage: "tornado")
            if let now = vortex.aktuell?.u10Ms {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Fmt.number(now, decimals: 1)) m/s")
                        .font(.title2.weight(.semibold))
                    Text(now >= 0 ? "Westwind (Wirbel intakt)" : "Ostwind (Umkehr)").font(.footnote)
                }
            }
            if let trend = vortex.trend7d {
                Text("7 Tage: \(trend.aenderungU10Ms.map { (($0 > 0) ? "+" : "") + Fmt.number($0, decimals: 1) + " m/s" } ?? "–"), \(trend.einordnung ?? "")")
                    .font(.footnote)
            }
            if let r = vortex.umkehrAufOst {
                Text(reversalText(r)).font(.footnote).opacity(0.9)
            }
            chart
            if let ens = vortex.ensembleEcmwf, let share = ens.anteilLaeufeMitUmkehrPct {
                Text("ECMWF-Ensemble: \(Fmt.number(share, decimals: 0)) % der Läufe mit Umkehr auf Ost.")
                    .font(.caption)
                    .opacity(0.85)
            }
            if let explain = vortex.kennwert {
                Text(explain).font(.caption2).opacity(0.7)
            }
        }
        .card()
    }

    private func reversalText(_ r: LargeScaleResponse.Reversal) -> String {
        if r.bereitsOst == true { return "Der Wind in 10 hPa weht bereits aus Ost." }
        guard r.erwartet == true else { return "Keine Umkehr auf Ost in Sicht." }
        var text = "Umkehr auf Ost erwartet"
        if let d = Fmt.parse(r.ersterTag) { text += " ab \(Fmt.weekdayShort(d)) \(Fmt.dayMonth(d))" }
        if let days = r.tageMitOst { text += ", \(days) Tage mit Ostwind" }
        if let back = Fmt.parse(r.wiederWestAb) { text += ", wieder West ab \(Fmt.dayMonth(back))" }
        return text + "."
    }

    @ViewBuilder
    private var chart: some View {
        let gfsTimes = ChartTime.dates(vortex.gfs?.time ?? [])
        let gfs = ChartSeries("GFS", color: Palette.model("gfs"), times: gfsTimes, values: vortex.gfs?.u10Ms?.expanded(gfsTimes.count) ?? [])
        let ensTimes = ChartTime.dates(vortex.ensembleEcmwf?.time ?? [])
        let ens = ChartSeries("ECMWF-Median", color: Palette.model("ecmwf"), times: ensTimes, values: vortex.ensembleEcmwf?.medianU10Ms?.expanded(ensTimes.count) ?? [])
        let all = (gfsTimes + ensTimes).compactMap { $0 }
        if let first = all.min(), let last = all.max(), last > first {
            Chart {
                RuleMark(y: .value("Null", 0.0))
                    .foregroundStyle(.white.opacity(0.5))
                ForEach(gfs.points) { p in
                    LineMark(x: .value("Tag", p.date), y: .value("m/s", p.value), series: .value("Reihe", "GFS"))
                        .foregroundStyle(gfs.color)
                }
                ForEach(ens.points) { p in
                    LineMark(x: .value("Tag", p.date), y: .value("m/s", p.value), series: .value("Reihe", "ECMWF"))
                        .foregroundStyle(ens.color)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
            }
            .chartXScale(domain: first...last)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(Fmt.dayMonth(d)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.number(v, decimals: 0)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .frame(height: 140)
            .accessibilityLabel("Zonalwind in 10 hPa, Vorhersage")
            HStack(spacing: 12) {
                Label("GFS", systemImage: "line.diagonal").foregroundStyle(gfs.color)
                Label("ECMWF-Ensemble Median", systemImage: "line.diagonal").foregroundStyle(ens.color)
            }
            .font(.caption2)
        }
    }
}

struct OscillationCard: View {
    let index: LargeScaleResponse.Oscillation
    let short: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(short).font(.headline)
            Text(index.index ?? "").font(.caption2).opacity(0.75).lineLimit(2)
            if let v = index.letzterWert {
                Text((v > 0 ? "+" : "") + Fmt.number(v, decimals: 2))
                    .font(.title2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(v >= 0 ? Palette.warm : Palette.cold)
            }
            Text("Phase \(index.phase ?? "–")").font(.footnote)
            if let t = index.trend14d?.einordnung {
                Text("Trend: \(t)").font(.caption).opacity(0.85)
            }
            if let d = Fmt.parse(index.datum) {
                Text("Stand \(Fmt.dayMonth(d))").font(.caption2).opacity(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }
}
