import SwiftUI

/// Headline and first sentence of today's report on the home screen, opens the Bericht tab.
struct ReportTeaser: View {
    let report: ReportResponse
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                CardTitle("Wetterbericht", systemImage: "newspaper", trailing: report.stand.map { shortStand($0) })
                if let headline = report.schlagzeile {
                    Text(headline)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let first = report.kurzfassung?.first {
                    Text(first)
                        .font(.system(.callout, design: .serif))
                        .multilineTextAlignment(.leading)
                        .opacity(0.9)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 4) {
                    Text("Ganzer Bericht")
                    Image(systemName: "chevron.right")
                }
                .font(.footnote.weight(.semibold))
                .opacity(0.85)
            }
            .card()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet den ganzen Wetterbericht")
    }

    /// "Mittwoch, 4. November, 17:46 Uhr" -> "17:46 Uhr".
    private func shortStand(_ text: String) -> String {
        text.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? text
    }
}
