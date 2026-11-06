import SwiftUI

// MARK: - next 24 hours

struct HourlyStrip: View {
    let items: [HourItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nächste 24 Stunden", systemImage: "clock")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.8)
            if items.isEmpty {
                Text("Keine Stundenwerte").font(.footnote).opacity(0.8)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 18) {
                        ForEach(items) { item in
                            HourCell(item: item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .card()
    }
}

struct HourCell: View {
    let item: HourItem

    var body: some View {
        VStack(spacing: 8) {
            Text(item.label)
                .font(.footnote.weight(item.label == "Jetzt" ? .bold : .regular))
            Image(systemName: item.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .frame(height: 30)
            Text(Fmt.temp(item.temp))
                .font(.title3.weight(.semibold))
            Text(rainText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(red: 0.62, green: 0.86, blue: 1.0))
                .frame(height: 14)
        }
        .frame(minWidth: 44)
        .accessibilityElement(children: .combine)
    }

    /// Rain chance from 10 %, otherwise nothing (keeps the strip calm).
    private var rainText: String {
        guard let p = item.rainProb, p >= 10 else { return " " }
        return Fmt.percent(p)
    }
}

// MARK: - 16 days

struct DailyList: View {
    let items: [DayItem]
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("\(items.count) Tage", systemImage: "calendar")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .opacity(0.8)
            if items.isEmpty {
                Text("Keine Tageswerte").font(.footnote).opacity(0.8)
            }
            ForEach(items) { item in
                Divider().overlay(.white.opacity(0.25))
                DayRow(item: item, range: range)
            }
        }
        .card()
    }
}

struct DayRow: View {
    let item: DayItem
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.label).font(.body.weight(.semibold))
                Text(item.dateLabel).font(.caption2).opacity(0.75)
            }
            .frame(width: 88, alignment: .leading)
            Image(systemName: item.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(width: 34)
            Text(rainText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.62, green: 0.86, blue: 1.0))
                .frame(width: 38, alignment: .leading)
            Text(Fmt.temp(item.tmin))
                .font(.callout)
                .opacity(0.8)
                .frame(width: 34, alignment: .trailing)
            TempBar(low: item.tmin, high: item.tmax, range: range)
                .frame(height: 6)
            Text(Fmt.temp(item.tmax))
                .font(.callout.weight(.semibold))
                .frame(width: 34, alignment: .trailing)
        }
        .opacity(item.confidence == "niedrig" ? 0.75 : 1)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label) \(item.dateLabel): \(Fmt.temp(item.tmin)) bis \(Fmt.temp(item.tmax)), Regen \(rainText)")
    }

    private var rainText: String {
        guard let p = item.rainProb, p >= 10 else { return "" }
        return Fmt.percent(p)
    }
}

/// Min-max bar of a day within the range of all days, coloured from cold to warm.
struct TempBar: View {
    let low: Double?
    let high: Double?
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let span = max(range.upperBound - range.lowerBound, 0.1)
            let lo = ((low ?? high ?? range.lowerBound) - range.lowerBound) / span
            let hi = ((high ?? low ?? range.upperBound) - range.lowerBound) / span
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [Self.color(low), Self.color(high)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * (hi - lo), 6))
                    .offset(x: geo.size.width * lo)
            }
        }
    }

    /// Blue below 0 °C, green-yellow mild, orange-red warm.
    static func color(_ t: Double?) -> Color {
        guard let t else { return .white }
        switch t {
        case ..<0: return Color(red: 0.55, green: 0.75, blue: 1.0)
        case ..<8: return Color(red: 0.45, green: 0.85, blue: 0.85)
        case ..<15: return Color(red: 0.70, green: 0.88, blue: 0.45)
        case ..<22: return Color(red: 1.0, green: 0.80, blue: 0.30)
        default: return Color(red: 1.0, green: 0.50, blue: 0.30)
        }
    }
}
