import SwiftUI

// MARK: - day / night

private struct IsNightKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Night at the location (sun times of the forecast), for the background gradient.
    var isNight: Bool {
        get { self[IsNightKey.self] }
        set { self[IsNightKey.self] = newValue }
    }
}

struct BackgroundGradient: View {
    let night: Bool

    var body: some View {
        LinearGradient(
            colors: night
                ? [Color(red: 0.04, green: 0.08, blue: 0.20), Color(red: 0.12, green: 0.19, blue: 0.36)]
                : [Color(red: 0.13, green: 0.42, blue: 0.82), Color(red: 0.38, green: 0.65, blue: 0.93)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The day/night gradient behind a whole screen (reads `isNight` from the environment).
struct ScreenBackground: ViewModifier {
    @Environment(\.isNight) private var night

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .background(BackgroundGradient(night: night).ignoresSafeArea())
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// Translucent card on the gradient.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.14)))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}

enum Palette {
    static let rain = Color(red: 0.62, green: 0.86, blue: 1.0)
    static let rainStrong = Color(red: 0.25, green: 0.55, blue: 1.0)
    static let warm = Color(red: 1.0, green: 0.62, blue: 0.35)
    static let cold = Color(red: 0.55, green: 0.80, blue: 1.0)
    static let wind = Color(red: 0.70, green: 0.95, blue: 0.80)
    static let sun = Color(red: 1.0, green: 0.85, blue: 0.35)
    static let muted = Color.white.opacity(0.7)

    /// Identity colours of the weather models (same model = same colour on every screen).
    static func model(_ id: String) -> Color {
        let key = id.lowercased()
        if key.hasPrefix("icon") { return Color(red: 0.36, green: 0.78, blue: 1.0) }
        if key.hasPrefix("ecmwf") || key.hasPrefix("ec46") || key == "ifs" { return Color(red: 1.0, green: 0.72, blue: 0.30) }
        if key.hasPrefix("gfs") || key.hasPrefix("gefs") { return Color(red: 0.62, green: 0.90, blue: 0.45) }
        if key.hasPrefix("arome") { return Color(red: 1.0, green: 0.50, blue: 0.62) }
        if key.hasPrefix("ukmo") { return Color(red: 0.78, green: 0.62, blue: 1.0) }
        if key.hasPrefix("mosmix") || key == "dwd" { return Color(red: 0.95, green: 0.95, blue: 0.95) }
        if key == "obs" || key.hasPrefix("mess") { return .white }
        return Color.white.opacity(0.6)
    }
}

// MARK: - building blocks

/// Small uppercase title of a card, optionally with a value on the right.
struct CardTitle: View {
    let text: String
    let systemImage: String
    var trailing: String?
    /// Glossary entry of the card's main value (info button next to the title).
    var info: String?

    init(_ text: String, systemImage: String, trailing: String? = nil, info: String? = nil) {
        self.text = text
        self.systemImage = systemImage
        self.trailing = trailing
        self.info = info
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Label(text, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing).font(.footnote)
                }
            }
            .opacity(0.8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if let info { InfoButton(info) }
        }
    }
}

/// Loading, error and empty states inside a card or a screen.
struct StateMessage: View {
    enum Kind { case loading, error, empty }

    let kind: Kind
    var text: String = ""
    var retry: (() async -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            switch kind {
            case .loading:
                ProgressView().tint(.white)
                Text(text.isEmpty ? "Lädt …" : text).font(.footnote).opacity(0.8)
            case .error:
                Image(systemName: "wifi.exclamationmark").font(.title2)
                Text(text).font(.footnote).multilineTextAlignment(.center)
                if let retry {
                    Button("Erneut laden") { Task { await retry() } }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
            case .empty:
                Image(systemName: "tray").font(.title2).opacity(0.8)
                Text(text.isEmpty ? "Keine Daten" : text).font(.footnote).multilineTextAlignment(.center).opacity(0.85)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .accessibilityElement(children: .combine)
    }
}

/// "Stand 17:43 Uhr" under a screen; offline it says that the stored answer is shown.
struct StandFooter: View {
    let date: Date?
    var fromCache = false
    var sources: String?

    var body: some View {
        VStack(spacing: 4) {
            if let date {
                if fromCache {
                    Label("Offline – gespeicherter Stand \(Fmt.relativeDateTime(date, reference: Date()))", systemImage: "icloud.slash")
                        .font(.caption.weight(.semibold))
                } else {
                    Text("Stand \(Fmt.time(date)) Uhr")
                }
            }
            if let sources {
                Text(sources)
            }
        }
        .font(.caption2)
        .opacity(0.75)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

/// Banner when a screen shows a stored answer because the server is not reachable.
struct OfflineBanner: View {
    let date: Date?

    var body: some View {
        Label {
            Text("Keine Verbindung. Gespeicherter Stand \(date.map { Fmt.relativeDateTime($0, reference: Date()) } ?? "unbekannt").")
        } icon: {
            Image(systemName: "icloud.slash")
        }
        .font(.footnote.weight(.semibold))
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.orange.opacity(0.35)))
    }
}

/// Key fact: small label above a value; `info` adds the glossary button next to the label.
struct Fact: View {
    let label: String
    let value: String
    var info: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).opacity(0.75)
                Text(value).font(.footnote.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if let info {
                InfoButton(info, compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - warning levels

/// DWD warning levels: 1 yellow, 2 orange, 3 red, 4 violet; Vorabinformation without level.
enum WarnLevel {
    static func color(_ level: Int?, pre: Bool = false) -> Color {
        if pre { return Color(red: 0.55, green: 0.60, blue: 0.70) }
        switch level ?? 1 {
        case ...1: return Color(red: 1.0, green: 0.86, blue: 0.20)
        case 2: return Color(red: 1.0, green: 0.58, blue: 0.10)
        case 3: return Color(red: 0.90, green: 0.18, blue: 0.16)
        default: return Color(red: 0.62, green: 0.20, blue: 0.70)
        }
    }

    /// Dark text on yellow and orange, white on red, violet and grey.
    static func ink(_ level: Int?, pre: Bool = false) -> Color {
        if pre { return .white }
        return (level ?? 1) <= 2 ? Color(red: 0.12, green: 0.10, blue: 0.05) : .white
    }

    static func title(_ warning: DwdWarning, pre: Bool) -> String {
        if pre { return "Vorabinformation" }
        let level = warning.stufe.map { "Stufe \($0)" } ?? "Warnung"
        if let text = warning.stufeText, !text.isEmpty { return "\(level) · \(text)" }
        return level
    }
}
