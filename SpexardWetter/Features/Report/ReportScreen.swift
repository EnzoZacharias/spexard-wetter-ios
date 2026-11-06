import Charts
import SwiftUI

enum ReportKind: String, CaseIterable, Identifiable {
    case heute, wochenende, woche

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heute: return "Heute"
        case .wochenende: return "Wochenende"
        case .woche: return "Woche"
        }
    }

    var endpoint: Endpoint {
        Endpoint(path: "/api/v1/wetterbericht?art=\(rawValue)", mock: "mock_bericht_\(rawValue)")
    }
}

/// Bericht tab: the server's written report for today, the weekend or the week.
struct ReportScreen: View {
    @StateObject private var loader = Loader<ReportResponse>()
    @AppStorage("berichtArt") private var kind: ReportKind = LaunchArgs.option.flatMap(ReportKind.init(rawValue:)) ?? .heute

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Bericht", selection: $kind) {
                            ForEach(ReportKind.allCases) { k in
                                Text(k.label).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)

                        if loader.fromCache { OfflineBanner(date: loader.date) }

                        if let report = loader.value, loader.endpoint == kind.endpoint || loader.loading {
                            ReportBody(report: report) { id in
                                withAnimation { proxy.scrollTo(id, anchor: .top) }
                            }
                            .opacity(loader.loading && loader.endpoint != nil ? 0.6 : 1)
                        } else if let error = loader.error {
                            StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                        } else {
                            StateMessage(kind: .loading, text: "Bericht wird geladen …").card()
                        }

                        StandFooter(date: loader.date, fromCache: loader.fromCache, sources: "Texte: eigener Wetterserver aus DWD-Berichten und Modelldaten")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    Haptics.armRefresh()
                    await loader.load(kind.endpoint)
                }
            }
            .screenBackground()
            .navigationTitle("Wetterbericht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let report = loader.value {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: Self.shareText(report)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Bericht teilen")
                    }
                }
            }
        }
        .task(id: kind) { await loader.loadIfNeeded(kind.endpoint, maxAge: 600) }
    }
}

extension ReportScreen {
    /// Plain text of the report for sharing: title, headline, summary and the sections.
    static func shareText(_ r: ReportResponse) -> String {
        var parts: [String] = []
        if let title = r.titel { parts.append(title) }
        if let headline = r.schlagzeile { parts.append(headline) }
        parts.append(contentsOf: r.kurzfassung ?? [])
        for section in r.abschnitte {
            let text = (section.absaetze ?? []).joined(separator: " ")
            if !text.isEmpty { parts.append("\(section.titel): \(text)") }
        }
        if let stand = r.stand { parts.append("Stand: \(stand)") }
        return parts.joined(separator: "\n\n")
    }
}

struct ReportBody: View {
    let report: ReportResponse
    let jump: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            lede
            if report.abschnitte.count > 2 {
                contents
            }
            ForEach(report.abschnitte) { section in
                ReportSectionCard(section: section)
                    .id(section.id)
            }
            if let missing = report.fehlendeAbschnitte, !missing.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    CardTitle("Fehlt in diesem Bericht", systemImage: "exclamationmark.circle")
                    ForEach(missing) { m in
                        Text("\(m.titel): \(m.grund ?? "keine Daten")").font(.footnote)
                    }
                }
                .card()
            }
            if let basis = report.grundlage, !basis.isEmpty {
                Text("Grundlage: " + basis.joined(separator: ", "))
                    .font(.caption)
                    .opacity(0.7)
            }
        }
    }

    private var lede: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text([report.untertitel, report.location?.label.map { "für \($0)" }].compactMap { $0 }.joined(separator: " "))
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.8)
            if let headline = report.schlagzeile {
                Text(headline)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array((report.kurzfassung ?? []).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.body, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let stand = report.stand {
                Text("Stand: \(stand)").font(.caption).opacity(0.75)
            }
        }
        .card()
    }

    /// Chips of the sections with their time span (jump to the section).
    private var contents: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(report.abschnitte) { section in
                    Button {
                        jump(section.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(section.titel).font(.footnote.weight(.semibold)).lineLimit(1)
                            if let period = ReportWords.period(section.zeitraum?.von, section.zeitraum?.bis) {
                                Text(period).font(.caption2).opacity(0.8).lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.white.opacity(0.16)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Springt zum Abschnitt")
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct ReportSectionCard: View {
    let section: ReportResponse.Section
    @Environment(\.openRoute) private var openRoute
    @State private var moreQuotes = false
    @State private var expert = false

    private static let quotesOpen = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(section.titel)
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                let period = ReportWords.period(section.zeitraum?.von, section.zeitraum?.bis)
                let level = ReportWords.confidenceLevel(section.konfidenz)
                if period != nil || level != nil {
                    HStack(spacing: 8) {
                        if let period { Text(period).font(.footnote).opacity(0.85) }
                        if let level { ConfidenceBadge(level: level, word: section.konfidenz ?? level) }
                    }
                }
            }

            if let kpis = section.kennzahlen, !kpis.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .topLeading)], alignment: .leading, spacing: 8) {
                    ForEach(kpis, id: \.self) { kpi in
                        KpiChip(kpi: kpi)
                    }
                }
            }

            if let spark = section.verlauf {
                ReportSparkline(spark: spark)
                    .frame(height: 86)
            }

            ForEach(Array((section.absaetze ?? []).enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(.body, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let questions = section.fragen, !questions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(questions, id: \.self) { q in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(q.frage).font(.callout.weight(.semibold))
                            Text(q.antwort).font(.callout).fixedSize(horizontal: false, vertical: true)
                            if let basis = q.grundlage {
                                Text("Grundlage: \(basis)").font(.caption).opacity(0.7)
                            }
                            if let link = q.link, let route = AppRoute(href: link.href) {
                                Button(link.text) { openRoute(route) }
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }

            if let quotes = section.zitate, !quotes.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(quotes.prefix(Self.quotesOpen).enumerated()), id: \.offset) { _, quote in
                        QuoteView(quote: quote)
                    }
                    if quotes.count > Self.quotesOpen {
                        DisclosureGroup(isExpanded: $moreQuotes) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(quotes.dropFirst(Self.quotesOpen).enumerated()), id: \.offset) { _, quote in
                                    QuoteView(quote: quote)
                                }
                            }
                            .padding(.top, 6)
                        } label: {
                            Text("Weitere DWD-Texte im Wortlaut (\(quotes.count - Self.quotesOpen))")
                                .font(.footnote.weight(.semibold))
                        }
                        .tint(.white)
                    }
                }
            }

            if let hint = section.hinweis, !hint.isEmpty {
                Label(hint, systemImage: "info.circle").font(.footnote).opacity(0.9)
            }

            if let basis = section.grundlage, !basis.isEmpty {
                Text("Grundlage: " + basis.joined(separator: ", "))
                    .font(.caption)
                    .opacity(0.7)
            }

            let routes = RouteLink.links(section.links)
            if !routes.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(routes) { link in
                            Button {
                                openRoute(link.route)
                            } label: {
                                Label(link.text, systemImage: "arrow.up.forward")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().strokeBorder(.white.opacity(0.5)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            let facts = section.fach ?? []
            if !facts.isEmpty || section.verlauf != nil {
                DisclosureGroup(isExpanded: $expert) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(facts.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.footnote).fixedSize(horizontal: false, vertical: true)
                        }
                        if let spark = section.verlauf {
                            HourTable(spark: spark)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Zahlen, Modelle und Stundenwerte").font(.footnote.weight(.semibold))
                }
                .tint(.white)
            }
        }
        .card()
    }
}

/// A server link that leads to a screen of the app.
struct RouteLink: Identifiable {
    let text: String
    let route: AppRoute
    let id: String

    static func links(_ links: [ReportResponse.Link]?) -> [RouteLink] {
        (links ?? []).compactMap { link in
            guard let route = AppRoute(href: link.href) else { return nil }
            return RouteLink(text: link.text, route: route, id: link.href)
        }
    }
}

struct ConfidenceBadge: View {
    let level: String
    let word: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("Konfidenz \(word)").font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.14)))
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch level {
        case "hoch": return .green
        case "mittel": return .yellow
        default: return .orange
        }
    }
}

struct KpiChip: View {
    let kpi: ReportResponse.Kpi

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if kpi.ton == "warnung" {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption2)
                }
                Text(kpi.label).font(.caption2).opacity(0.85)
            }
            Text(kpi.wert).font(.callout.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(background))
        .accessibilityElement(children: .combine)
    }

    private var background: Color {
        switch kpi.ton {
        case "warnung": return Color.orange.opacity(0.45)
        case "hinweis": return Color.yellow.opacity(0.25)
        default: return Color.white.opacity(0.12)
        }
    }
}

struct QuoteView: View {
    let quote: ReportResponse.Quote

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.5)).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text("„\(quote.text)“")
                    .font(.system(.callout, design: .serif).italic())
                    .fixedSize(horizontal: false, vertical: true)
                if let source = quote.quelle {
                    Text(source).font(.caption).opacity(0.75)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Small hourly temperature curve of a section (model median of the server).
struct ReportSparkline: View {
    let spark: ReportResponse.Spark

    private struct Point: Identifiable {
        let id: Int
        let date: Date
        let temp: Double
    }

    private var points: [Point] {
        let temps = spark.tC?.expanded(spark.time.count) ?? []
        return spark.time.enumerated().compactMap { i, text in
            guard let date = Fmt.parse(text), temps.indices.contains(i), let t = temps[i] else { return nil }
            return Point(id: i, date: date, temp: t)
        }
    }

    var body: some View {
        let pts = points
        let lo = pts.map(\.temp).min() ?? 0
        let hi = pts.map(\.temp).max() ?? 1
        let minPoint = pts.first { $0.temp == lo }
        let maxPoint = pts.first { $0.temp == hi }
        if pts.count >= 2 {
            Chart {
                ForEach(pts) { p in
                    AreaMark(x: .value("Zeit", p.date), yStart: .value("Basis", lo - 1), yEnd: .value("Temperatur", p.temp))
                        .foregroundStyle(LinearGradient(colors: [Palette.warm.opacity(0.35), Palette.warm.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Zeit", p.date), y: .value("Temperatur", p.temp))
                        .foregroundStyle(Palette.warm)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                }
                if let maxPoint {
                    PointMark(x: .value("Zeit", maxPoint.date), y: .value("Temperatur", maxPoint.temp))
                        .foregroundStyle(Palette.warm)
                        .annotation(position: .top, spacing: 2) {
                            Text(Fmt.temp(maxPoint.temp)).font(.caption2.weight(.semibold))
                        }
                }
                if let minPoint, minPoint.id != maxPoint?.id {
                    PointMark(x: .value("Zeit", minPoint.date), y: .value("Temperatur", minPoint.temp))
                        .foregroundStyle(Palette.cold)
                        .annotation(position: .bottom, spacing: 2) {
                            Text(Fmt.temp(minPoint.temp)).font(.caption2.weight(.semibold))
                        }
                }
            }
            .chartYScale(domain: (lo - 1)...(hi + 1.5))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(Fmt.time(date)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Temperaturverlauf")
            .accessibilityValue("von \(Fmt.temp(lo)) bis \(Fmt.temp(hi))")
        }
    }
}

struct HourTable: View {
    let spark: ReportResponse.Spark

    var body: some View {
        let temps = spark.tC?.expanded(spark.time.count) ?? []
        let rain = spark.regenPct?.expanded(spark.time.count) ?? []
        Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 4) {
            GridRow {
                Text("Zeit").gridColumnAlignment(.leading)
                Text("Temperatur")
                Text("Regenrisiko")
            }
            .font(.caption.weight(.semibold))
            .opacity(0.8)
            ForEach(Array(spark.time.enumerated()), id: \.offset) { i, time in
                GridRow {
                    Text(Fmt.parse(time).map { Fmt.time($0) } ?? "–")
                    Text(Fmt.temp(temps.indices.contains(i) ? temps[i] : nil, decimals: 1))
                    Text(Fmt.percent(rain.indices.contains(i) ? rain[i] : nil))
                }
                .font(.caption.monospacedDigit())
            }
        }
        if let source = spark.quelle {
            Text("Quelle: \(source)").font(.caption2).opacity(0.7)
        }
    }
}
