import Charts
import SwiftUI
import WidgetKit

/// Colours of the wind rows: calm in muted blue-grey, then green, yellow, orange, red and violet
/// with rising Beaufort number (own scale).
enum WindScale {
    static func color(_ kmh: Double?) -> Color {
        guard let kmh else { return Color.white.opacity(0.08) }
        switch Beaufort.number(kmh) {
        case ...1: return Color(red: 0.42, green: 0.52, blue: 0.62)
        case 2: return Color(red: 0.36, green: 0.60, blue: 0.68)
        case 3: return Color(red: 0.30, green: 0.68, blue: 0.62)
        case 4: return Color(red: 0.42, green: 0.76, blue: 0.42)
        case 5: return Color(red: 0.76, green: 0.82, blue: 0.32)
        case 6: return Color(red: 0.98, green: 0.80, blue: 0.26)
        case 7: return Color(red: 0.98, green: 0.58, blue: 0.22)
        case 8: return Color(red: 0.92, green: 0.36, blue: 0.24)
        case 9: return Color(red: 0.80, green: 0.18, blue: 0.26)
        default: return Color(red: 0.62, green: 0.22, blue: 0.64)
        }
    }

    /// Dark text on the light middle of the scale, white elsewhere.
    static func ink(_ kmh: Double?) -> Color {
        guard let kmh else { return .white }
        let b = Beaufort.number(kmh)
        return (4...7).contains(b) ? Color(red: 0.10, green: 0.10, blue: 0.08) : .white
    }
}

/// "Verlauf & Live": current values of the stations plus the next hours in 3-hour columns.
struct LiveStripWidget: View {
    let family: WidgetFamily
    let snapshot: WidgetSnapshot?
    var placeholder = false

    var body: some View {
        if placeholder {
            WidgetPlaceholder()
        } else if let s = snapshot {
            if family == .systemLarge {
                large(s)
            } else {
                medium(s)
            }
        } else {
            WidgetNoData()
        }
    }

    // MARK: medium: one live line, 9 columns

    private func medium(_ s: WidgetSnapshot) -> some View {
        let live = s.live
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 6) {
                Text(Fmt.temp(live.temp.value, decimals: 1))
                    .font(.system(size: 21, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.shortPlace)
                        .font(.system(size: 10, weight: .semibold))
                    Text(live.temp.shortSource + " " + Fmt.time(live.temp.time))
                        .font(.system(size: 8))
                        .opacity(0.7)
                }
                .lineLimit(1)
                .layoutPriority(1)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Self.climateLine(live))
                    Text(Self.windLine(live))
                }
                .font(.system(size: 9.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            ForecastStrip(columns: Array(s.strip.prefix(9)), compact: true)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(s))
    }

    // MARK: large: live block with sources, 13 columns

    private func large(_ s: WidgetSnapshot) -> some View {
        let live = s.live
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(s.shortPlace).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        WidgetWarningMark(snapshot: s)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Fmt.temp(live.temp.value, decimals: 1))
                            .font(.system(size: 38, weight: .light))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Image(systemName: s.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 20))
                    }
                    Text(live.temp.sourceText)
                        .font(.system(size: 9))
                        .opacity(0.75)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 128, alignment: .leading)
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        LiveFact(title: "Taupunkt", value: live.dewPoint.map { Fmt.temp($0.value, decimals: 1) }, model: live.dewPoint?.measured == false)
                        LiveFact(title: "Feuchte", value: live.humidity.map { Fmt.percent($0.value) }, model: live.humidity?.measured == false)
                    }
                    GridRow {
                        LiveFact(title: "Wind", value: live.wind.map { Fmt.number($0.value, decimals: 0) + " km/h" + (live.windDir.map { " " + Fmt.compass($0) } ?? "") }, model: live.wind?.measured == false)
                        LiveFact(title: "Böen", value: live.gust.map { Fmt.wind($0.value) }, model: live.gust?.measured == false)
                    }
                    GridRow {
                        LiveFact(title: "Luftdruck", value: live.pressure.map { Fmt.value($0.value, 0, "hPa") }, model: live.pressure?.measured == false)
                        if let rain = live.rain1h, rain.value > 0 {
                            LiveFact(title: "Regen 1 h", value: Fmt.precip(rain.value), model: false)
                        } else {
                            LiveFact(title: "Himmel", value: s.sky, model: false)
                        }
                    }
                }
            }
            if !live.stations.isEmpty {
                Text("Gemessen: " + live.stations.joined(separator: " · "))
                    .font(.system(size: 8))
                    .opacity(0.65)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            ForecastStrip(columns: Array(s.strip.prefix(13)), compact: false)
            HStack(spacing: 8) {
                Text("Zeilen: Regen mm in 3 h · Regenrisiko % · Wind · Böen km/h · Pfeil: wohin der Wind weht")
                Spacer(minLength: 0)
                Text(Fmt.time(live.temp.time ?? s.stand))
            }
            .font(.system(size: 8))
            .opacity(0.6)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(s))
    }

    // MARK: words

    /// "Taupunkt 2,6° · 77 % · 1031 hPa" (+ "· Regen 0,3 mm" in the last hour).
    static func climateLine(_ live: LiveValues) -> String {
        var parts: [String] = []
        if let d = live.dewPoint { parts.append("Taupunkt " + Fmt.temp(d.value, decimals: 1)) }
        if let h = live.humidity { parts.append(Fmt.percent(h.value)) }
        if let p = live.pressure { parts.append(Fmt.value(p.value, 0, "hPa")) }
        if let r = live.rain1h, r.value > 0 { parts.append("Regen " + Fmt.precip(r.value)) }
        return parts.joined(separator: " · ")
    }

    /// "Wind Ost 16 km/h · Böen 24".
    static func windLine(_ live: LiveValues) -> String {
        var parts: [String] = []
        if let w = live.wind {
            let dir = live.windDir.map { Fmt.compass($0) + " " } ?? ""
            parts.append("Wind " + dir + Fmt.wind(w.value))
        }
        if let g = live.gust { parts.append("Böen " + Fmt.number(g.value, decimals: 0)) }
        return parts.joined(separator: " · ")
    }

    static func accessibilityText(_ s: WidgetSnapshot) -> String {
        let live = s.live
        var text = "\(s.shortPlace) \(Fmt.temp(live.temp.value, decimals: 1)). \(climateLine(live)). \(windLine(live))."
        if let last = s.strip.last {
            let temps = s.strip.compactMap(\.temp)
            if let lo = temps.min(), let hi = temps.max() {
                text += " Bis \(Fmt.time(last.id)) Uhr \(Fmt.temp(lo)) bis \(Fmt.temp(hi))"
            }
            let rain = s.strip.compactMap(\.precip).reduce(0, +)
            text += rain > 0 ? ", zusammen \(Fmt.precip(rain)) Niederschlag." : ", trocken."
        }
        return text
    }
}

/// Small label with a value; "M" marks a model value where no station measures.
struct LiveFact: View {
    let title: String
    let value: String?
    let model: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 9)).opacity(0.7)
            HStack(spacing: 2) {
                Text(value ?? "–").font(.system(size: 12, weight: .semibold))
                if model {
                    Text("Modell").font(.system(size: 7, weight: .semibold)).opacity(0.6)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }
}

/// The columns: hour (weekday at a new day), symbol, filled temperature curve with the values,
/// precipitation, wind and gust rows in the wind colours, direction arrows; night columns darker.
struct ForecastStrip: View {
    let columns: [StripColumn]
    let compact: Bool

    var body: some View {
        let temps = columns.compactMap(\.temp)
        let lo = (temps.min() ?? 0) - 1.5
        let hi = (temps.max() ?? 1) + (compact ? 3.5 : 3)
        VStack(spacing: compact ? 1 : 5) {
            row { c in
                Text(c.day ?? c.hour)
                    .font(.system(size: compact ? 9 : 11, weight: c.day == nil ? .medium : .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            row { c in
                Image(systemName: c.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: compact ? 11 : 18))
                    .frame(height: compact ? 13 : 24)
            }
            curve(lo: lo, hi: hi)
                .frame(height: compact ? 27 : 70)
            // precipitation always shown: "0" for a dry step (dimmed), "–" without a value
            row { c in
                Text(Self.precipText(c.precip))
                    .font(.system(size: compact ? 8 : 10, weight: .semibold))
                    .foregroundStyle(Palette.rain)
                    .opacity((c.precip ?? 0) >= 0.1 ? 1 : 0.45)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if !compact {
                row { c in
                    Text(c.rainProb.map { Fmt.number($0, decimals: 0) } ?? "–")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Palette.rain)
                        .opacity((c.rainProb ?? 0) >= 10 ? 1 : 0.45)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            row { c in WindCell(kmh: c.wind, height: compact ? 12 : 19) }
            row { c in WindCell(kmh: c.gust, height: compact ? 12 : 19) }
            row { c in
                if let dir = c.windDir {
                    // drawn pointing up = north; turned to where the air moves (from + 180°)
                    Image(systemName: "arrow.up")
                        .font(.system(size: compact ? 8 : 12, weight: .bold))
                        .rotationEffect(.degrees(dir + 180))
                        .frame(height: compact ? 10 : 15)
                } else {
                    Text(" ").font(.system(size: 8))
                }
            }
        }
        .padding(.vertical, 2)
        .background {
            // night columns darker (sunset to sunrise of the server's sun times)
            HStack(spacing: 0) {
                ForEach(columns) { c in
                    Rectangle().fill(c.night ? Color.black.opacity(0.24) : Color.white.opacity(0.03))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    /// "0,3" (mm), "0" for less than 0,1 mm, "–" without a value.
    static func precipText(_ mm: Double?) -> String {
        guard let mm else { return "–" }
        guard mm >= 0.1 else { return "0" }
        return Fmt.number(mm, decimals: mm < 10 ? 1 : 0)
    }

    private func row<Cell: View>(@ViewBuilder _ cell: @escaping (StripColumn) -> Cell) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { c in
                cell(c).frame(maxWidth: .infinity)
            }
        }
    }

    private struct Point: Identifiable {
        let id: Int
        let temp: Double
    }

    private func curve(lo: Double, hi: Double) -> some View {
        let points = columns.enumerated().compactMap { i, c in c.temp.map { Point(id: i, temp: $0) } }
        let n = Swift.max(columns.count, 1)
        return Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Spalte", Double(p.id)), yStart: .value("Basis", lo), yEnd: .value("Temperatur", p.temp))
                    .foregroundStyle(LinearGradient(colors: [Palette.warm.opacity(0.55), Palette.warm.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Spalte", Double(p.id)), y: .value("Temperatur", p.temp))
                    .foregroundStyle(Palette.warm)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Spalte", Double(p.id)), y: .value("Temperatur", p.temp))
                    .symbolSize(compact ? 6 : 10)
                    .foregroundStyle(.white)
                    .annotation(position: .top, spacing: 0) {
                        Text(Fmt.temp(p.temp))
                            .font(.system(size: compact ? 9 : 10, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
        }
        .chartXScale(domain: -0.5...(Double(n) - 0.5))
        .chartYScale(domain: lo...Swift.max(hi, lo + 1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct WindCell: View {
    let kmh: Double?
    let height: CGFloat

    var body: some View {
        Text(kmh.map { Fmt.number($0, decimals: 0) } ?? "–")
            .font(.system(size: height < 14 ? 8 : 10, weight: .bold))
            .foregroundStyle(WindScale.ink(kmh))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(RoundedRectangle(cornerRadius: 2).fill(WindScale.color(kmh)))
            .padding(.horizontal, 0.5)
    }
}
