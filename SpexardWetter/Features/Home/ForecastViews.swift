import SwiftUI

// MARK: - next 24 hours

/// Small "Meteogramm ›" style link in a card title.
struct MoreLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(title)
                Image(systemName: "chevron.right")
            }
            .font(.footnote.weight(.semibold))
            .opacity(0.85)
        }
        .buttonStyle(.plain)
    }
}

enum HourlyMode: String, CaseIterable, Identifiable {
    case regen, wind, luft

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regen: return "Regen"
        case .wind: return "Wind"
        case .luft: return "Luft"
        }
    }
}

struct HourlyStrip: View {
    let items: [HourItem]
    var sunEvents: [SunEvent] = []
    var more: (() -> Void)?
    @State private var mode: HourlyMode = .regen

    private enum Entry: Identifiable {
        case hour(HourItem)
        case sun(SunEvent)

        var date: Date {
            switch self {
            case .hour(let h): return h.id
            case .sun(let s): return s.id
            }
        }

        var id: String {
            switch self {
            case .hour(let h): return "h\(h.id.timeIntervalSince1970)"
            case .sun(let s): return "s\(s.id.timeIntervalSince1970)"
            }
        }
    }

    /// Hours with sunrise and sunset placed between them.
    private var entries: [Entry] {
        (items.map { Entry.hour($0) } + sunEvents.map { Entry.sun($0) }).sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Nächste 24 Stunden", systemImage: "clock")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .opacity(0.8)
                Spacer()
                if let more { MoreLink(title: "Meteogramm", action: more) }
            }
            if items.isEmpty {
                Text("Keine Stundenwerte").font(.footnote).opacity(0.8)
            } else {
                Picker("Zusatzwert", selection: $mode) {
                    ForEach(HourlyMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(entries) { entry in
                            switch entry {
                            case .hour(let item): HourCell(item: item, mode: mode)
                            case .sun(let event): SunCell(event: event)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                if mode == .luft {
                    Text("Tp = Taupunkt (nur solange die Kurzfrist-Modelle rechnen), darunter die Bewölkung")
                        .font(.caption2)
                        .opacity(0.7)
                }
            }
        }
        .card()
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// Sunrise or sunset between the hours.
struct SunCell: View {
    let event: SunEvent

    var body: some View {
        VStack(spacing: 8) {
            Text(Fmt.time(event.id)).font(.footnote)
            Image(systemName: event.rise ? "sunrise.fill" : "sunset.fill")
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .frame(height: 30)
            Text(event.rise ? "Aufgang" : "Untergang")
                .font(.caption.weight(.semibold))
        }
        .frame(minWidth: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sonnen\(event.rise ? "aufgang" : "untergang") \(Fmt.time(event.id)) Uhr")
    }
}

struct HourCell: View {
    let item: HourItem
    var mode: HourlyMode = .regen

    var body: some View {
        VStack(spacing: 8) {
            Text(item.label)
                .font(.footnote)
            Image(systemName: item.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .frame(height: 30)
            Text(Fmt.temp(item.temp))
                .font(.title3.weight(.semibold))
            if mode == .luft {
                // dew point and cloud cover of the hour (dew point only for short-range hours)
                VStack(spacing: 2) {
                    Text(item.dewPoint.map { "Tp " + Fmt.temp($0) } ?? " ")
                        .font(.caption2.weight(.semibold))
                    Text(item.cloud.map { "\(Int($0.rounded())) %" } ?? " ")
                        .font(.system(size: 9))
                        .opacity(0.8)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 9))
                        .opacity(0.25 + 0.75 * ((item.cloud ?? 0) / 100))
                }
                .foregroundStyle(Palette.cold)
                .frame(height: 40)
            } else if mode == .wind {
                VStack(spacing: 2) {
                    if let dir = item.windDir {
                        // the arrow points where the wind blows to (from the direction + 180°)
                        Image(systemName: "location.north.fill")
                            .font(.caption2)
                            .rotationEffect(.degrees(dir + 180))
                    }
                    Text(item.wind.map { Fmt.number($0, decimals: 0) } ?? "–")
                        .font(.caption2.weight(.semibold))
                    Text(item.gust.map { "Böen " + Fmt.number($0, decimals: 0) } ?? " ")
                        .font(.system(size: 9))
                        .opacity(0.75)
                }
                .foregroundStyle(Palette.wind)
                .frame(height: 40)
            } else {
                VStack(spacing: 2) {
                    Text(rainText)
                        .font(.caption2.weight(.semibold))
                    Text(mmText)
                        .font(.system(size: 9))
                        .opacity(0.8)
                }
                .foregroundStyle(Palette.rain)
                .frame(height: 40)
            }
        }
        .frame(minWidth: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var mmText: String {
        guard let mm = item.precip, mm >= 0.1 else { return " " }
        return Fmt.precip(mm)
    }

    private var accessibilityText: String {
        var text = "\(item.label): \(Fmt.temp(item.temp))"
        if let p = item.rainProb, p >= 10 { text += ", Regenrisiko \(Fmt.percent(p))" }
        if let mm = item.precip, mm > 0 { text += ", \(Fmt.precip(mm))" }
        if let w = item.wind { text += ", Wind \(Fmt.wind(w))\(item.windDir.map { " aus " + Fmt.compass($0) } ?? "")" }
        if let d = item.dewPoint { text += ", Taupunkt \(Fmt.temp(d))" }
        if let c = item.cloud { text += ", Bewölkung \(Fmt.percent(c))" }
        return text
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
    var onSelect: ((String) -> Void)?
    var more: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(items.count) Tage", systemImage: "calendar")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .opacity(0.8)
                Spacer()
                if let more { MoreLink(title: "Trend", action: more) }
            }
            if items.isEmpty {
                Text("Keine Tageswerte").font(.footnote).opacity(0.8)
            }
            ForEach(items) { item in
                Divider().overlay(.white.opacity(0.25))
                Button {
                    onSelect?(item.id)
                } label: {
                    DayRow(item: item, range: range)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Zeigt den Tag im Detail")
            }
        }
        .card()
        // dense rows with fixed columns: grow with the text size, but not beyond what still fits
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

struct DayRow: View {
    let item: DayItem
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.label)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(item.dateLabel).font(.caption2).opacity(0.75)
            }
            .frame(width: 92, alignment: .leading)
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
