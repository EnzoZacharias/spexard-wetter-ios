import Charts
import SwiftUI
import WidgetKit

/// Content of the widgets per family (also rendered in the app's widget preview).
struct WidgetContent: View {
    let family: WidgetFamily
    let snapshot: WidgetSnapshot?
    var placeholder = false

    var body: some View {
        if placeholder {
            WidgetPlaceholder()
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium: MediumWidget(snapshot: snapshot)
        case .accessoryRectangular: RectangularWidget(snapshot: snapshot)
        case .accessoryCircular: CircularWidget(snapshot: snapshot)
        case .accessoryInline: InlineWidget(snapshot: snapshot)
        default: SmallWidget(snapshot: snapshot)
        }
    }
}

/// Small coloured triangle when the DWD warns (level colour; grey for a Vorabinformation).
struct WidgetWarningMark: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.warningTitle != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(WarnLevel.color(snapshot.warningLevel, pre: snapshot.warningIsPre))
                .accessibilityLabel("Amtliche Warnung")
        }
    }
}

struct SmallWidget: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let s = snapshot {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(s.shortPlace).font(.footnote.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    WidgetWarningMark(snapshot: s)
                }
                Text(Fmt.temp(s.temp))
                    .font(.system(size: 44, weight: .light))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: s.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                if let sky = s.sky {
                    Text(sky).font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                }
                if s.min != nil || s.max != nil {
                    Text("Max \(Fmt.temp(s.max)) · Min \(Fmt.temp(s.min))")
                        .font(.caption2)
                        .opacity(0.85)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        } else {
            WidgetNoData()
        }
    }
}

struct MediumWidget: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let s = snapshot {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(s.shortPlace).font(.footnote.weight(.semibold)).lineLimit(1)
                            WidgetWarningMark(snapshot: s)
                        }
                        Text(s.offline ? "Stand \(Fmt.time(s.time ?? s.stand))" : Fmt.time(s.time ?? s.stand))
                            .font(.caption2)
                            .opacity(0.7)
                        HStack(alignment: .center, spacing: 6) {
                            Text(Fmt.temp(s.temp))
                                .font(.system(size: 40, weight: .light))
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                            Image(systemName: s.symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.title2)
                        }
                        if s.min != nil || s.max != nil {
                            Text("Max \(Fmt.temp(s.max)) · Min \(Fmt.temp(s.min))")
                                .font(.caption2)
                                .opacity(0.85)
                                .lineLimit(1)
                        }
                    }
                    .frame(width: 118, alignment: .leading)
                    HStack(spacing: 0) {
                        ForEach(s.hours.prefix(5)) { hour in
                            VStack(spacing: 4) {
                                Text(Fmt.hour(hour.id))
                                    .font(.caption2.weight(.medium))
                                Image(systemName: hour.symbol)
                                    .symbolRenderingMode(.multicolor)
                                    .font(.callout)
                                    .frame(height: 20)
                                Text(Fmt.temp(hour.temp)).font(.footnote.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                Spacer(minLength: 0)
                if let warning = s.warningTitle {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                } else if let rain = s.rainHeadline {
                    Label(rain, systemImage: "cloud.rain")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        } else {
            WidgetNoData()
        }
    }
}

struct RectangularWidget: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let s = snapshot {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: s.symbol)
                    Text("\(s.shortPlace) \(Fmt.temp(s.temp))").font(.headline).lineLimit(1)
                    if s.warningTitle != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                }
                if s.min != nil || s.max != nil {
                    Text("Max \(Fmt.temp(s.max)) · Min \(Fmt.temp(s.min))").font(.caption).lineLimit(1)
                }
                Text(s.warningTitle ?? s.rainHeadline ?? s.sky ?? "")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            Text("Keine Daten").font(.caption)
        }
    }
}

struct CircularWidget: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: snapshot?.symbol ?? "questionmark")
                    .font(.system(size: 15))
                Text(Fmt.temp(snapshot?.temp))
                    .font(.system(size: 19, weight: .semibold))
                    .minimumScaleFactor(0.6)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct InlineWidget: View {
    let snapshot: WidgetSnapshot?

    var body: some View {
        if let s = snapshot {
            Label("\(Fmt.temp(s.temp)) \(s.rainHeadline ?? s.sky ?? "")", systemImage: s.symbol)
        } else {
            Text("Keine Wetterdaten")
        }
    }
}

struct WidgetNoData: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "wifi.exclamationmark").font(.title3)
            Text("Keine Verbindung zum Wetterserver").font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Rain widget: the nowcast sentence and the 2-hour bars of the DWD radar at the location.
struct RainWidgetContent: View {
    let family: WidgetFamily
    let snapshot: WidgetSnapshot?
    var placeholder = false

    var body: some View {
        if placeholder {
            WidgetPlaceholder()
        } else if let s = snapshot {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    Label(s.rainHeadline ?? "Keine Radardaten", systemImage: "cloud.rain")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    RainBars(steps: s.rainSteps, tinted: false, axis: false)
                        .frame(height: 22)
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Regen in 2 Stunden", systemImage: "cloud.rain")
                            .font(.caption.weight(.semibold))
                            .opacity(0.85)
                        Spacer()
                        Text(s.shortPlace).font(.caption2).opacity(0.7)
                    }
                    Text(s.rainHeadline ?? "Keine Radardaten")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    RainBars(steps: s.rainSteps, tinted: true, axis: true)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityElement(children: .combine)
            }
        } else {
            WidgetNoData()
        }
    }
}

/// 5-minute bars (mm/h) with the start of the forecast marked; only the zero line when dry.
struct RainBars: View {
    let steps: [NowcastResponse.Step]
    let tinted: Bool
    let axis: Bool

    var body: some View {
        let top = max(1, (steps.compactMap(\.mmh).max() ?? 0) * 1.1)
        let first = steps.first.map { $0.end.addingTimeInterval(-300) } ?? Date()
        let last = max(steps.last?.end ?? first, first.addingTimeInterval(600))
        let forecastStart = steps.first(where: { $0.forecast }).map { $0.end.addingTimeInterval(-300) }
        let base = Chart {
            RuleMark(y: .value("null", 0.0))
                .foregroundStyle(.white.opacity(0.4))
            if let forecastStart {
                RuleMark(x: .value("Prognose", forecastStart))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            ForEach(steps) { step in
                if let v = step.mmh, v > 0 {
                    RectangleMark(
                        xStart: .value("Beginn", step.end.addingTimeInterval(-290)),
                        xEnd: .value("Ende", step.end.addingTimeInterval(-10)),
                        yStart: .value("unten", 0.0),
                        yEnd: .value("mm/h", v)
                    )
                    .foregroundStyle(tinted ? Palette.rain : Color.white)
                }
            }
        }
        .chartXScale(domain: first...last)
        .chartYScale(domain: 0...top)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
        if axis {
            base.chartXAxis {
                AxisMarks(values: .stride(by: .minute, count: 30)) { value in
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(Fmt.time(d)).font(.system(size: 9))
                        }
                    }
                }
            }
        } else {
            base.chartXAxis(.hidden)
        }
    }
}

/// Grey placeholder while the system prepares the widget (no invented values).
struct WidgetPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Spexard").font(.footnote.weight(.semibold))
            Text("00°").font(.system(size: 40, weight: .light))
            Text("Wetter wird geladen").font(.caption)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .redacted(reason: .placeholder)
    }
}
