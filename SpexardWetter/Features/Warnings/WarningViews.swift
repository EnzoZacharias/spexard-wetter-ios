import SwiftUI

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

/// Banner at the top of the home screen while the DWD has warnings or Vorabinformationen for the
/// municipality. Shows the first one; nothing when there are none or the source is down.
struct WarningBanner: View {
    let block: WarningBlock
    let reference: Date
    let action: () -> Void

    var body: some View {
        if let top = block.top {
            let pre = block.topIsPre
            let more = block.totalCount - 1
            Button(action: action) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: pre ? "exclamationmark.bubble.fill" : "exclamationmark.triangle.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WarnLevel.title(top, pre: pre))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .opacity(0.85)
                        Text(top.title)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        Text(subtitle(top, more: more))
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .opacity(0.7)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(WarnLevel.ink(top.stufe, pre: pre))
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(WarnLevel.color(top.stufe, pre: pre))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(.white.opacity(pre ? 0.5 : 0), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Amtliche Warnung: \(WarnLevel.title(top, pre: pre)). \(top.title). \(subtitle(top, more: more))")
            .accessibilityHint("Zeigt alle Warnungen")
        }
    }

    private func subtitle(_ warning: DwdWarning, more: Int) -> String {
        var text = warning.whenText(reference: reference)
        if let area = block.gebiet, !area.isEmpty { text += " für \(area)" }
        if more > 0 { text += more == 1 ? ", dazu 1 weitere" : ", dazu \(more) weitere" }
        return text
    }
}

/// One warning with all texts of the DWD.
struct WarningCard: View {
    let warning: DwdWarning
    let pre: Bool
    let reference: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(WarnLevel.title(warning, pre: pre))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(WarnLevel.ink(warning.stufe, pre: pre))
                    .background(Capsule().fill(WarnLevel.color(warning.stufe, pre: pre)))
                if let status = warning.status {
                    Text(status).font(.caption.weight(.semibold)).opacity(0.8)
                }
            }
            Text(warning.title).font(.headline)
            Text(period).font(.footnote).opacity(0.85)
            if let description = warning.beschreibung, !description.isEmpty {
                Text(description).font(.callout)
            }
            if let hints = warning.hinweise, !hints.isEmpty {
                Text(hints).font(.footnote).opacity(0.85)
            }
            if let height = heightText {
                Label(height, systemImage: "mountain.2").font(.footnote).opacity(0.85)
            }
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var period: String {
        let start = Fmt.parse(warning.beginn).map { Fmt.relativeDateTime($0, reference: reference) }
        let end = Fmt.parse(warning.ende).map { Fmt.relativeDateTime($0, reference: reference) }
        switch (start, end) {
        case let (s?, e?): return "\(s) bis \(e)"
        case let (s?, nil): return "ab \(s), ohne Endzeit"
        case let (nil, e?): return "bis \(e)"
        default: return "ohne Zeitangabe"
        }
    }

    private var heightText: String? {
        switch (warning.hoeheAbM, warning.hoeheBisM) {
        case let (from?, to?): return "Gilt von \(Int(from)) bis \(Int(to)) m Höhe"
        case let (from?, nil): return "Gilt ab \(Int(from)) m Höhe"
        case let (nil, to?): return "Gilt bis \(Int(to)) m Höhe"
        default: return nil
        }
    }
}

/// All warnings and Vorabinformationen of the block, or the calm state.
struct WarningList: View {
    let block: WarningBlock?
    let reference: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let block {
                if !block.known {
                    StateMessage(kind: .error, text: "Die Warnungen des DWD sind gerade nicht abrufbar (\(block.status ?? "unbekannt")).")
                        .card()
                } else if block.totalCount == 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.title)
                            .foregroundStyle(.green, .white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keine Warnungen").font(.headline)
                            Text("Der DWD warnt derzeit nicht für \(block.gebiet ?? "den Ort").").font(.footnote).opacity(0.85)
                        }
                    }
                    .card()
                    .accessibilityElement(children: .combine)
                } else {
                    ForEach(block.warnings) { warning in
                        WarningCard(warning: warning, pre: false, reference: reference)
                    }
                    ForEach(block.preWarnings) { warning in
                        WarningCard(warning: warning, pre: true, reference: reference)
                    }
                }
                if let hint = block.hinweisVeraltet ?? block.hinweis, !hint.isEmpty {
                    Text(hint).font(.footnote).opacity(0.8)
                }
                if let source = block.quelle {
                    Text("Quelle: \(source)").font(.caption2).opacity(0.7)
                }
            } else {
                StateMessage(kind: .empty, text: "Keine Warndaten vom Server.").card()
            }
        }
    }
}

/// Sheet from the home banner: the warnings of the municipality.
struct WarningsSheet: View {
    let block: WarningBlock?
    let reference: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                WarningList(block: block, reference: reference)
                    .padding(16)
            }
            .screenBackground()
            .navigationTitle("Amtliche Warnungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
