import Charts
import SwiftUI

/// One series of a time chart (already aligned values; nil = gap).
struct ChartSeries: Identifiable {
    enum Style { case line, bars, area, points }

    struct Point: Identifiable {
        let id: Int
        let date: Date
        let value: Double
    }

    let id: String
    let color: Color
    var style: Style = .line
    var dashed = false
    var points: [Point]

    init(_ label: String, color: Color, style: Style = .line, dashed: Bool = false, times: [Date?], values: [Double?]) {
        id = label
        self.color = color
        self.style = style
        self.dashed = dashed
        var out: [Point] = []
        for (i, date) in times.enumerated() {
            guard let date, values.indices.contains(i), let v = values[i], v.isFinite else { continue }
            out.append(Point(id: i, date: date, value: v))
        }
        points = out
    }

    var isEmpty: Bool { points.isEmpty }
}

enum ChartTime {
    /// Times of the server ("2026-11-04T17:00+01:00") as dates (nil where unreadable).
    static func dates(_ times: [String]) -> [Date?] { times.map { Fmt.parse($0) } }

    /// Axis ticks aligned to full Berlin hours: every 3/6/12 hours, every day or every second day,
    /// by span (so the labels never collide on a phone).
    static func ticks(from start: Date, to end: Date) -> [Date] {
        let hours = end.timeIntervalSince(start) / 3600
        let step: Int
        switch hours {
        case ..<4: step = 1
        case ..<13: step = 3
        case ..<30: step = 6
        case ..<80: step = 12
        default: step = 24
        }
        let everyOtherDay = hours > 200
        let cal = Fmt.calendar
        guard var t = cal.dateInterval(of: .hour, for: start)?.start else { return [] }
        if t < start { t = t.addingTimeInterval(3600) }
        var out: [Date] = []
        var guardCount = 0
        while t <= end && guardCount < 2000 {
            let h = cal.component(.hour, from: t)
            if h % step == 0 {
                if everyOtherDay {
                    let day = cal.ordinality(of: .day, in: .era, for: t) ?? 0
                    if day % 2 == 0 { out.append(t) }
                } else {
                    out.append(t)
                }
            }
            t = t.addingTimeInterval(3600)
            guardCount += 1
        }
        return out
    }

    /// "18" for hours, the short weekday at midnight ("Do"), or "Do 6" for daily ticks.
    static func label(_ date: Date, daily: Bool) -> String {
        let cal = Fmt.calendar
        if daily { return "\(Fmt.weekdayShort(date)) \(cal.component(.day, from: date))" }
        if cal.component(.hour, from: date) == 0 { return Fmt.weekdayShort(date) }
        return Fmt.hour(date)
    }

    /// Nights between sunset and sunrise from `[date, sunrise "07:25", sunset "16:52"]` days.
    static func nights(_ days: [(date: String, sunrise: String?, sunset: String?)], within range: ClosedRange<Date>) -> [ClosedRange<Date>] {
        var sunsets: [Date] = []
        var sunrises: [Date] = []
        for day in days {
            guard let d = Fmt.parse(day.date) else { continue }
            if let rise = WeatherDerived.clock(day.sunrise, on: d) { sunrises.append(rise) }
            if let set = WeatherDerived.clock(day.sunset, on: d) { sunsets.append(set) }
        }
        var out: [ClosedRange<Date>] = []
        // night before the first sunrise
        if let firstRise = sunrises.min(), firstRise > range.lowerBound {
            out.append(range.lowerBound...min(firstRise, range.upperBound))
        }
        for set in sunsets.sorted() {
            let rise = sunrises.filter { $0 > set }.min() ?? range.upperBound
            let a = max(set, range.lowerBound)
            let b = min(rise, range.upperBound)
            if a < b { out.append(a...b) }
        }
        return out
    }
}

/// Card with a title, a small legend and a Swift Charts time chart.
struct TimeChart: View {
    let title: String
    var subtitle: String?
    let unit: String
    let series: [ChartSeries]
    let domain: ClosedRange<Date>
    var nights: [ClosedRange<Date>] = []
    var zeroBased = false
    var minSpan: Double = 1
    var decimals = 0
    var height: CGFloat = 140
    var now: Date?
    var barWidth: TimeInterval = 3600
    /// Shown over the chart when every value is 0 (e.g. "kein Niederschlag").
    var zeroText: String?
    /// Glossary entry behind the chart (info button next to the title).
    var info: String?
    /// Glossary ids whose current notes of the server ("Was heißt das jetzt") appear under the chart.
    var notes: [String] = []

    private var values: [Double] { series.flatMap { $0.points.map(\.value) } }

    private var yDomain: ClosedRange<Double> {
        var lo = values.min() ?? 0
        var hi = values.max() ?? 1
        if zeroBased { lo = min(0, lo) }
        if hi - lo < minSpan {
            if zeroBased {
                hi = lo + minSpan
            } else {
                let mid = (lo + hi) / 2
                lo = mid - minSpan / 2
                hi = mid + minSpan / 2
            }
        }
        let pad = (hi - lo) * 0.08
        return (zeroBased ? lo : lo - pad)...(hi + pad)
    }

    private var ticks: [Date] { ChartTime.ticks(from: domain.lowerBound, to: domain.upperBound) }
    private var daily: Bool { domain.upperBound.timeIntervalSince(domain.lowerBound) >= 80 * 3600 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).accessibilityHidden(true)
                if let info { InfoButton(info, compact: true) }
                Spacer(minLength: 6)
                Text(unit).font(.caption).opacity(0.7).accessibilityHidden(true)
            }
            chartBlock
            if !notes.isEmpty { GlossaryNotesView(notes, compact: true) }
        }
        .card()
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let subtitle {
                Text(subtitle).font(.caption2).opacity(0.7)
            }
            if series.count > 1 {
                HStack(spacing: 12) {
                    ForEach(series) { s in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(s.color)
                                .frame(width: 12, height: s.style == .line ? 3 : 8)
                            Text(s.id).font(.caption2)
                        }
                    }
                }
                .opacity(0.9)
            }
            if values.isEmpty {
                StateMessage(kind: .empty, text: "Keine Werte im Zeitraum")
                    .frame(height: height)
            } else {
                chart
                    .frame(height: height)
                    .overlay {
                        if let zeroText, values.allSatisfy({ $0 == 0 }) {
                            Text(zeroText)
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.black.opacity(0.25)))
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) in \(unit)")
        .accessibilityValue(accessibilitySummary)
    }

    private var chart: some View {
        let y = yDomain
        return Chart {
            ForEach(Array(nights.enumerated()), id: \.offset) { _, night in
                RectangleMark(
                    xStart: .value("Nacht von", night.lowerBound),
                    xEnd: .value("Nacht bis", night.upperBound),
                    yStart: .value("unten", y.lowerBound),
                    yEnd: .value("oben", y.upperBound)
                )
                .foregroundStyle(.black.opacity(0.18))
            }
            ForEach(series) { s in
                ForEach(s.points) { p in
                    if s.style == .bars {
                        RectangleMark(
                            xStart: .value("Beginn", p.date.addingTimeInterval(-barWidth * 0.9)),
                            xEnd: .value("Ende", p.date.addingTimeInterval(-barWidth * 0.1)),
                            yStart: .value("Null", max(0, y.lowerBound)),
                            yEnd: .value(s.id, p.value)
                        )
                        .foregroundStyle(s.color)
                    } else if s.style == .area {
                        AreaMark(
                            x: .value("Zeit", p.date),
                            y: .value(s.id, p.value),
                            series: .value("Reihe", s.id),
                            stacking: .unstacked
                        )
                        .foregroundStyle(s.color.opacity(0.35))
                        .interpolationMethod(.monotone)
                    } else if s.style == .points {
                        PointMark(x: .value("Zeit", p.date), y: .value(s.id, p.value))
                            .foregroundStyle(s.color)
                            .symbolSize(14)
                    } else {
                        LineMark(x: .value("Zeit", p.date), y: .value(s.id, p.value), series: .value("Reihe", s.id))
                            .foregroundStyle(s.color)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: s.dashed ? [4, 3] : []))
                            .interpolationMethod(.monotone)
                    }
                }
            }
            if let now, domain.contains(now) {
                RuleMark(x: .value("Jetzt", now))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: y)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.12))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(ChartTime.label(date, daily: daily)).foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.12))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Fmt.number(v, decimals: decimals)).foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
        }
    }

    private var accessibilitySummary: String {
        series.compactMap { s -> String? in
            let vals = s.points.map(\.value)
            guard let lo = vals.min(), let hi = vals.max() else { return nil }
            return "\(s.id) von \(Fmt.number(lo, decimals: decimals)) bis \(Fmt.number(hi, decimals: decimals)) \(unit)"
        }.joined(separator: "; ")
    }
}
