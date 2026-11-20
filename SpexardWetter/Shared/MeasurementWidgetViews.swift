import AppIntents
import SwiftUI
import WidgetKit

/// The quantity of the "Messwert" widget, chosen in the widget's settings (long press → Widget bearbeiten).
enum MeasurementKind: String, AppEnum, CaseIterable {
    case temperatur, taupunkt, feuchte, wind, boeen, luftdruck, regen, sicht, luft, pollen, uv, mond

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Messgröße"
    static var caseDisplayRepresentations: [MeasurementKind: DisplayRepresentation] = [
        .temperatur: "Temperatur",
        .taupunkt: "Taupunkt",
        .feuchte: "Luftfeuchte",
        .wind: "Wind",
        .boeen: "Böen",
        .luftdruck: "Luftdruck",
        .regen: "Regen der letzten Stunde",
        .sicht: "Sichtweite",
        .luft: "Luftqualität (UBA)",
        .pollen: "Pollenflug heute",
        .uv: "UV-Index heute",
        .mond: "Mond",
    ]

    /// Values of `/api/v1/umwelt` instead of `weather_now`.
    var isEnvironment: Bool { [.luft, .pollen, .uv, .mond].contains(self) }

    var label: String {
        switch self {
        case .temperatur: return "Temperatur"
        case .taupunkt: return "Taupunkt"
        case .feuchte: return "Luftfeuchte"
        case .wind: return "Wind"
        case .boeen: return "Böen"
        case .luftdruck: return "Luftdruck"
        case .regen: return "Regen 1 h"
        case .sicht: return "Sicht"
        case .luft: return "Luft"
        case .pollen: return "Pollen"
        case .uv: return "UV-Index"
        case .mond: return "Mond"
        }
    }

    var systemImage: String {
        switch self {
        case .temperatur: return "thermometer.medium"
        case .taupunkt: return "drop.degreesign"
        case .feuchte: return "humidity"
        case .wind: return "wind"
        case .boeen: return "tornado"
        case .luftdruck: return "gauge.with.dots.needle.33percent"
        case .regen: return "cloud.rain"
        case .sicht: return "eye"
        case .luft: return "aqi.medium"
        case .pollen: return "leaf.fill"
        case .uv: return "sun.max.trianglebadge.exclamationmark"
        case .mond: return "moon.stars.fill"
        }
    }
}

/// One current value of `weather_now`: measured at a DWD station (or the own sensor), the model
/// value next to it (ICON-D2), where and when.
struct MeasurementWidgetData {
    let kind: MeasurementKind
    /// "2,6°", "77 %", "16 km/h", "1031 hPa".
    let value: String
    let measured: Bool
    /// "Bielefeld-Deppendorf", "Gartensensor", "Modell ICON-D2".
    let source: String
    let time: Date?
    /// "Modell 2,4°" when the shown value is measured and the model has one too.
    let model: String?
    /// "aus Nordost · 3 Bft" (wind, gusts), "Spread 3,7 K" (dew point).
    let extra: String?
    let offline: Bool

    static func load(_ kind: MeasurementKind) async -> MeasurementWidgetData? {
        if kind.isEnvironment {
            guard let result: Fetched<EnvironmentResponse> = try? await APIClient().fetch(.environment, timeout: 15) else { return nil }
            return MeasurementWidgetData(kind, environment: result.value, offline: result.fromCache)
        }
        guard let result: Fetched<WeatherNow> = try? await APIClient().fetch(.now, timeout: 15) else { return nil }
        return MeasurementWidgetData(kind, now: result.value, offline: result.fromCache)
    }

    /// Air, pollen, UV and moon from `/api/v1/umwelt` (nil while the server has none).
    init?(_ kind: MeasurementKind, environment e: EnvironmentResponse, offline: Bool) {
        self.kind = kind
        self.offline = offline
        model = nil
        switch kind {
        case .luft:
            guard let air = e.luft, let text = air.text else { return nil }
            value = text
            measured = true
            source = "UBA " + (air.station ?? "Station")
            time = Fmt.parse(air.stand)
            extra = air.index.map { "Index \($0) von 4" }
        case .pollen:
            guard let types = e.pollen?.arten, !types.isEmpty else { return nil }
            let today = types.compactMap { t -> (String, EnvironmentResponse.PollenDay)? in
                guard let d = t.heute, (d.wert ?? 0) > 0 else { return nil }
                return (t.name ?? t.id, d)
            }.sorted { ($0.1.wert ?? 0) > ($1.1.wert ?? 0) }
            if let top = today.first {
                value = top.0 + " " + (top.1.stufe ?? "").replacingOccurrences(of: "-", with: "–")
                extra = today.count > 1 ? today.dropFirst().prefix(2).map { "\($0.0) \(($0.1.stufe ?? "").replacingOccurrences(of: "-", with: "–"))" }.joined(separator: " · ") : top.1.text
            } else {
                value = "keine"
                extra = "keine der \(types.count) Arten"
            }
            measured = false
            source = "DWD Ostwestfalen"
            time = Fmt.parse(e.pollen?.ausgabe)
        case .uv:
            guard let day = e.uv?.heute, let index = day.uvIndex else { return nil }
            value = Fmt.number(index, decimals: 0)
            measured = false
            extra = [day.stufe, e.uv?.morgen?.uvIndex.map { "morgen " + Fmt.number($0, decimals: 0) }].compactMap { $0 }.joined(separator: " · ")
            source = "DWD " + (e.uv?.ort ?? "")
            time = Fmt.parse(e.uv?.ausgabe)
        case .mond:
            guard let moon = e.astro?.mond, let pct = moon.beleuchtungPct else { return nil }
            value = "\(Int(pct.rounded())) %"
            measured = false
            extra = moon.phase
            source = "berechnet"
            time = Fmt.parse(moon.beleuchtungUm)
        default:
            return nil
        }
    }

    init?(_ kind: MeasurementKind, now: WeatherNow, offline: Bool) {
        self.kind = kind
        self.offline = offline
        let n = now.now
        let measuredTime = Fmt.parse(now.measuredTime)
        let modelTime = Fmt.parse(now.modelTime)
        func fill(_ pair: WeatherNow.Pair?, _ text: (Double) -> String) -> (String, Bool, String, Date?, String?)? {
            guard let best = pair?.best else { return nil }
            let model = best.measured ? pair?.model.map { "Modell " + text($0) } : nil
            let source = best.measured ? (pair?.station ?? "DWD-Station") : "Modell ICON-D2"
            return (text(best.value), best.measured, source, best.measured ? measuredTime : modelTime, model)
        }
        var extra: String?
        let filled: (String, Bool, String, Date?, String?)?
        switch kind {
        case .temperatur:
            let current = WeatherDerived.currentTemp(now)
            guard let v = current.value else { return nil }
            let source: String
            switch current.source {
            case .local: source = current.name ?? "Gartensensor"
            case .station: source = current.name ?? "DWD-Station"
            default: source = "Modell ICON-D2"
            }
            let model = current.source == .model ? nil : n?.temperatureC?.model.map { "Modell " + Fmt.temp($0, decimals: 1) }
            filled = (Fmt.temp(v, decimals: 1), current.source != .model, source, current.time, model)
        case .taupunkt:
            filled = fill(n?.dewPointC) { Fmt.temp($0, decimals: 1) }
            // spread = temperature minus dew point (fog when it gets small)
            if let t = n?.temperatureC?.measured ?? n?.temperatureC?.model, let td = n?.dewPointC?.best?.value {
                extra = "Spread " + Fmt.value(t - td, 1, "K")
            }
        case .feuchte:
            filled = fill(n?.humidityPct) { Fmt.percent($0) }
        case .wind:
            filled = fill(n?.windSpeedKmh) { Fmt.wind($0) }
            extra = Self.windExtra(n?.windSpeedKmh?.best?.value, direction: n?.windDirectionDeg?.best?.value)
        case .boeen:
            if let max60 = n?.windGustsKmh?.measuredMax60min {
                let model = n?.windGustsKmh?.model.map { "Modell " + Fmt.wind($0) }
                filled = (Fmt.wind(max60), true, n?.windGustsKmh?.station ?? "DWD-Station", measuredTime, model)
                extra = "stärkste der letzten Stunde · \(Beaufort.number(max60)) Bft"
            } else {
                filled = fill(n?.windGustsKmh) { Fmt.wind($0) }
                extra = n?.windGustsKmh?.best.map { "\(Beaufort.number($0.value)) Bft" }
            }
        case .luftdruck:
            filled = fill(n?.pressureMslHpa) { Fmt.value($0, 0, "hPa") }
            extra = "auf Meereshöhe"
        case .regen:
            if let mm = n?.precipitationMm?.measured60min {
                filled = (Fmt.precip(mm), true, n?.precipitationMm?.station ?? "DWD-Station", measuredTime, nil)
            } else {
                filled = nil
            }
        case .sicht:
            filled = fill(n?.visibilityM) { Self.visibility($0) }
        case .luft, .pollen, .uv, .mond:
            return nil
        }
        guard let f = filled else { return nil }
        value = f.0
        measured = f.1
        source = f.2
        time = f.3
        model = f.4
        self.extra = extra
    }

    /// "aus Nordost · 3 Bft".
    static func windExtra(_ kmh: Double?, direction: Double?) -> String? {
        var parts: [String] = []
        if let direction { parts.append("aus " + Fmt.compass(direction)) }
        if let kmh { parts.append("\(Beaufort.number(kmh)) Bft") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "75 km" / "800 m".
    static func visibility(_ m: Double) -> String {
        m >= 1000 ? Fmt.value(m / 1000, m < 10000 ? 1 : 0, "km") : Fmt.value(m, 0, "m")
    }
}

/// "Messwert" widget: one current value with its station, time and the model next to it.
struct MeasurementWidgetContent: View {
    let family: WidgetFamily
    let data: MeasurementWidgetData?
    let kind: MeasurementKind
    var placeholder = false

    var body: some View {
        if placeholder {
            WidgetPlaceholder()
        } else if let d = data {
            switch family {
            case .accessoryCircular: circular(d)
            case .accessoryRectangular: rectangular(d)
            case .accessoryInline: Label(Self.titled(d), systemImage: d.kind.systemImage)
            default: small(d)
            }
        } else if family == .systemSmall {
            VStack(alignment: .leading, spacing: 4) {
                Label(kind.label, systemImage: kind.systemImage).font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text("Kein Wert vom Wetterserver").font(.caption)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text("\(kind.label) –").font(.caption)
        }
    }

    private func small(_ d: MeasurementWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(d.kind.label, systemImage: d.kind.systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(d.value)
                .font(.system(size: 36, weight: .light))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let extra = d.extra {
                Text(extra).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            Text(d.source).font(.caption2).lineLimit(1).minimumScaleFactor(0.7).opacity(0.85)
            HStack(spacing: 4) {
                RefreshTimeButton(text: d.offline ? "Stand \(Fmt.time(d.time))" : Fmt.time(d.time), font: .system(size: 10))
                if let model = d.model {
                    Text("· " + model).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .opacity(0.75)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(d))
    }

    private func rectangular(_ d: MeasurementWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(Self.titled(d), systemImage: d.kind.systemImage)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(d.extra ?? d.source).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
            Text([Fmt.time(d.time), d.model].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(d))
    }

    private func circular(_ d: MeasurementWidgetData) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: d.kind.systemImage).font(.system(size: 13))
                Text(Self.circularValue(d.value))
                    .font(.system(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
            }
            .padding(4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.accessibilityText(d))
    }

    /// Number above its unit ("1031\nhPa"); a one-character unit stays on the line ("77 %").
    static func circularValue(_ value: String) -> String {
        guard let space = value.lastIndex(of: " "), value[value.index(after: space)...].count > 1 else { return value }
        return value.replacingCharacters(in: space...space, with: "\n")
    }

    /// "Luftdruck 1031 hPa", but "Pollen: keine" when the value is a word.
    static func titled(_ d: MeasurementWidgetData) -> String {
        guard let first = d.value.first, first.isLetter else { return "\(d.kind.label) \(d.value)" }
        return "\(d.kind.label): \(d.value)"
    }

    static func accessibilityText(_ d: MeasurementWidgetData) -> String {
        var parts = ["\(d.kind.label) \(d.value)"]
        if let extra = d.extra { parts.append(extra) }
        parts.append((d.measured ? "gemessen " : "") + d.source + " " + Fmt.time(d.time))
        if let model = d.model { parts.append(model) }
        return parts.joined(separator: ", ")
    }
}
