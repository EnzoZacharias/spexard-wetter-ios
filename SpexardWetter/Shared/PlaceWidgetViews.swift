import SwiftUI
import WidgetKit

/// What the "Ort" widget shows for a place of choice (`/api/v1/ort`): the model value of the
/// current hour, today's range, the next hours and the first DWD warning of its municipality.
struct PlaceWidgetData {
    let name: String
    let temp: Double?
    let symbol: String
    let sky: String?
    let max: Double?
    let min: Double?
    let rainProb: Double?
    /// "Niederschlag ab etwa 02:00 Uhr" (next 12 hours).
    let rainNext: String?
    /// Every third hour from now (medium widget).
    let hours: [HourItem]
    let warningTitle: String?
    let warningLevel: Int?
    let time: Date?
    let offline: Bool

    static func load(_ place: Place) async -> PlaceWidgetData? {
        guard let result: Fetched<PlaceForecastResponse> = try? await APIClient().fetch(place.forecastEndpoint, timeout: 15) else { return nil }
        return PlaceWidgetData(result.value, name: place.name, offline: result.fromCache)
    }

    init?(_ data: PlaceForecastResponse, name: String, offline: Bool) {
        guard data.jetzt != nil || data.tage != nil else { return nil }
        let now = data.jetzt
        let today = data.tage?.first
        self.name = name
        temp = now?.temperaturC
        symbol = WeatherSymbol.name(code: now?.wetterCode, night: now?.istTag == false)
        sky = now?.wetter.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        max = today?.maxC
        min = today?.minC
        rainProb = today?.regenWahrscheinlichkeitPct
        rainNext = data.rainNext()
        hours = Array(data.hourItems().enumerated().filter { $0.offset % 3 == 0 }.map { $0.element }.prefix(5))
        let top = (data.warnungen ?? []).max { ($0.stufe ?? 0) < ($1.stufe ?? 0) }
        warningTitle = top.map { CalmText.calm($0.title) }
        warningLevel = top?.stufe
        time = Fmt.parse(now?.zeit)
        self.offline = offline
    }
}

/// "Amtliche WARNUNG vor STURMBÖEN" -> "Amtliche Warnung vor Sturmböen" (Siri and the widgets).
enum CalmText {
    static func calm(_ text: String) -> String {
        text.split(separator: " ").map { word -> String in
            let w = String(word)
            return w.count > 1 && w == w.uppercased() && w.rangeOfCharacter(from: .letters) != nil ? w.capitalized : w
        }.joined(separator: " ")
    }
}

/// "Ort" widget: a place of choice, set with "Widget bearbeiten" (model values, no measurement).
struct PlaceWidgetContent: View {
    let family: WidgetFamily
    let data: PlaceWidgetData?
    /// Name of the chosen place (nil: none chosen yet).
    let placeName: String?
    var placeholder = false

    var body: some View {
        if placeholder {
            WidgetPlaceholder()
        } else if placeName == nil {
            hint("Ort wählen: Widget lange drücken, „Widget bearbeiten“ und einen Ort suchen.")
        } else if let d = data {
            switch family {
            case .accessoryRectangular: rectangular(d)
            case .systemMedium: medium(d)
            default: small(d)
            }
        } else {
            hint("Keine Vorhersage für \(placeName ?? "den Ort") vom Wetterserver.")
        }
    }

    private func hint(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "mappin.and.ellipse").font(.title3)
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ d: PlaceWidgetData) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse").font(.caption2)
            Text(d.name).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            if d.warningTitle != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WarnLevel.color(d.warningLevel))
                    .accessibilityLabel("Amtliche Warnung")
            }
        }
    }

    private func small(_ d: PlaceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header(d)
            Text(Fmt.temp(d.temp))
                .font(.system(size: 42, weight: .light))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: d.symbol).symbolRenderingMode(.multicolor).font(.title3)
            Text(d.warningTitle ?? d.sky ?? "").font(.caption.weight(.medium)).lineLimit(1).minimumScaleFactor(0.7)
            if d.min != nil || d.max != nil {
                Text("Max \(Fmt.temp(d.max)) · Min \(Fmt.temp(d.min))").font(.caption2).opacity(0.85).lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func medium(_ d: PlaceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    header(d)
                    RefreshTimeButton(text: "Modell " + Fmt.time(d.time))
                        .opacity(0.7)
                    HStack(spacing: 6) {
                        Text(Fmt.temp(d.temp)).font(.system(size: 38, weight: .light)).lineLimit(1).minimumScaleFactor(0.6)
                        Image(systemName: d.symbol).symbolRenderingMode(.multicolor).font(.title2)
                    }
                    if d.min != nil || d.max != nil {
                        Text("Max \(Fmt.temp(d.max)) · Min \(Fmt.temp(d.min))").font(.caption2).opacity(0.85).lineLimit(1)
                    }
                }
                .frame(width: 124, alignment: .leading)
                HStack(spacing: 0) {
                    ForEach(d.hours) { hour in
                        VStack(spacing: 4) {
                            Text(Fmt.hour(hour.id)).font(.caption2.weight(.medium))
                            Image(systemName: hour.symbol).symbolRenderingMode(.multicolor).font(.callout).frame(height: 20)
                            Text(Fmt.temp(hour.temp)).font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer(minLength: 0)
            if let warning = d.warningTitle {
                Label(warning, systemImage: "exclamationmark.triangle.fill").font(.caption2.weight(.semibold)).lineLimit(1)
            } else if let rain = d.rainNext {
                Label(rain, systemImage: "cloud.rain").font(.caption2.weight(.semibold)).lineLimit(1)
            } else if let sky = d.sky {
                Text(sky + (d.rainProb.map { " · Regenrisiko heute \(Fmt.percent($0))" } ?? "")).font(.caption2.weight(.semibold)).lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    private func rectangular(_ d: PlaceWidgetData) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: d.symbol)
                Text("\(d.name) \(Fmt.temp(d.temp))").font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            }
            if d.min != nil || d.max != nil {
                Text("Max \(Fmt.temp(d.max)) · Min \(Fmt.temp(d.min))").font(.caption).lineLimit(1)
            }
            Text(d.warningTitle ?? d.sky ?? "").font(.caption).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
