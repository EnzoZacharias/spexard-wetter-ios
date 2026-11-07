import SwiftUI
import WidgetKit

/// What the history widget shows, from `/api/v1/historie?zeitraum=monate`: today so far in the
/// garden, the current month and the records of the sensor.
struct HistoryWidgetData {
    struct Value {
        let celsius: Double
        /// "04 Uhr" (only the hour known) or "04:12", for longer periods "6.11.".
        let when: String?
    }

    let todayLow: Value?
    let todayHigh: Value?
    let todayHours: Int?
    let monthLabel: String?
    let monthLow: Value?
    let monthHigh: Value?
    /// Mean of the month's complete days minus the normal 1991–2020.
    let monthDeviation: Double?
    let recordHigh: Value?
    let recordLow: Value?
    let recordsSince: Date?
    let stand: Date
    let offline: Bool

    static func load() async -> HistoryWidgetData? {
        guard let result: Fetched<HistoryResponse> = try? await APIClient().fetch(HistoryUnit.monate.endpoint, timeout: 15) else { return nil }
        return HistoryWidgetData(result.value, stand: result.date, offline: result.fromCache)
    }

    init?(_ data: HistoryResponse, stand: Date, offline: Bool) {
        guard let garden = data.garten else { return nil }
        func clock(_ time: String?, exact: Bool?) -> String? {
            guard let t = Fmt.parse(time) else { return nil }
            return exact == true ? Fmt.time(t) : "\(Fmt.hour(t)) Uhr"
        }
        func day(_ time: String?) -> String? { Fmt.parse(time).map(Fmt.dayMonth) }
        let today = garden.heute
        todayLow = today?.tminC.map { Value(celsius: $0, when: clock(today?.tminZeit, exact: nil)) }
        todayHigh = today?.tmaxC.map { Value(celsius: $0, when: clock(today?.tmaxZeit, exact: nil)) }
        todayHours = today?.stunden
        let month = garden.perioden?.last
        monthLabel = month?.label
        monthLow = month?.tminC.map { Value(celsius: $0, when: day(month?.tminZeit)) }
        monthHigh = month?.tmaxC.map { Value(celsius: $0, when: day(month?.tmaxZeit)) }
        monthDeviation = month?.abweichungK
        let records = garden.rekorde
        recordHigh = records?.hoechstwert?.wertC.map { Value(celsius: $0, when: day(records?.hoechstwert?.datum)) }
        recordLow = records?.tiefstwert?.wertC.map { Value(celsius: $0, when: day(records?.tiefstwert?.datum)) }
        recordsSince = Fmt.parse(records?.seit)
        self.stand = stand
        self.offline = offline
        if todayLow == nil, monthLow == nil, recordHigh == nil { return nil }
    }

    /// "November 2026" -> "November".
    var monthName: String? { monthLabel?.split(separator: " ").first.map(String.init) }
}

/// "Historie" widget: today so far in the garden, the month and the records.
struct HistoryWidgetContent: View {
    let family: WidgetFamily
    let data: HistoryWidgetData?
    var placeholder = false

    var body: some View {
        if placeholder {
            WidgetPlaceholder()
        } else if let d = data {
            switch family {
            case .accessoryRectangular: rectangular(d)
            case .systemMedium: medium(d)
            default: small(d)
            }
        } else {
            WidgetNoData()
        }
    }

    private func small(_ d: HistoryWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Garten heute", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
            valueLine("arrow.down", d.todayLow, color: Palette.cold, size: 22)
            valueLine("arrow.up", d.todayHigh, color: Palette.warm, size: 22)
            Spacer(minLength: 0)
            if let name = d.monthName, let lo = d.monthLow, let hi = d.monthHigh {
                Text("\(name): \(Fmt.temp(lo.celsius, decimals: 1)) bis \(Fmt.temp(hi.celsius, decimals: 1))")
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let dev = d.monthDeviation {
                Text(Self.deviationText(dev))
                    .font(.system(size: 9.5))
                    .opacity(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(d))
    }

    private func medium(_ d: HistoryWidgetData) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Label("Garten heute", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                valueLine("arrow.down", d.todayLow, color: Palette.cold, size: 24)
                valueLine("arrow.up", d.todayHigh, color: Palette.warm, size: 24)
                Spacer(minLength: 0)
                if let hours = d.todayHours {
                    Text("\(hours) Stunden mit Daten · \(Fmt.time(d.stand))")
                        .font(.system(size: 9))
                        .opacity(0.7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                if let name = d.monthName {
                    block(name, low: d.monthLow, high: d.monthHigh, note: d.monthDeviation.map(Self.deviationText))
                }
                block(
                    "Rekorde" + (d.recordsSince.map { " seit \(Fmt.dayMonth($0))" } ?? ""),
                    low: d.recordLow,
                    high: d.recordHigh,
                    note: nil
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(d))
    }

    private func rectangular(_ d: HistoryWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Garten heute").font(.system(size: 12, weight: .semibold))
            Text("↓ \(Fmt.temp(d.todayLow?.celsius, decimals: 1))  ↑ \(Fmt.temp(d.todayHigh?.celsius, decimals: 1))")
                .font(.system(size: 15, weight: .semibold))
            if let name = d.monthName, let lo = d.monthLow, let hi = d.monthHigh {
                Text("\(name) \(Fmt.temp(lo.celsius, decimals: 1)) bis \(Fmt.temp(hi.celsius, decimals: 1))")
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(d))
    }

    private func valueLine(_ icon: String, _ v: HistoryWidgetData.Value?, color: Color, size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(color)
            Text(Fmt.temp(v?.celsius, decimals: 1))
                .font(.system(size: size, weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let when = v?.when {
                Text(when).font(.system(size: 9.5)).opacity(0.75).lineLimit(1)
            }
        }
    }

    private func block(_ title: String, low: HistoryWidgetData.Value?, high: HistoryWidgetData.Value?, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 10, weight: .semibold)).opacity(0.8).lineLimit(1)
            HStack(spacing: 8) {
                if let low {
                    Text("↓ \(Fmt.temp(low.celsius, decimals: 1))").foregroundStyle(Palette.cold)
                        + Text(low.when.map { " \($0)" } ?? "").font(.system(size: 9))
                }
                if let high {
                    Text("↑ \(Fmt.temp(high.celsius, decimals: 1))").foregroundStyle(Palette.warm)
                        + Text(high.when.map { " \($0)" } ?? "").font(.system(size: 9))
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            if let note {
                Text(note).font(.system(size: 9)).opacity(0.75).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    /// "−0,9 K zum Normal" (mean of the complete days).
    static func deviationText(_ v: Double) -> String {
        (v > 0 ? "+" : "") + Fmt.number(v, decimals: 1) + " K zum Normal"
    }

    static func accessibilityText(_ d: HistoryWidgetData) -> String {
        var parts = ["Garten heute bisher: tiefster Wert \(Fmt.temp(d.todayLow?.celsius, decimals: 1)), höchster Wert \(Fmt.temp(d.todayHigh?.celsius, decimals: 1))"]
        if let name = d.monthName, let lo = d.monthLow, let hi = d.monthHigh {
            parts.append("\(name) \(Fmt.temp(lo.celsius, decimals: 1)) bis \(Fmt.temp(hi.celsius, decimals: 1))")
        }
        if let dev = d.monthDeviation { parts.append(deviationText(dev)) }
        return parts.joined(separator: ". ")
    }
}
