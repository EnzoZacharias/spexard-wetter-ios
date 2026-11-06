import SwiftUI

/// Home: the server's notes on conspicuous professional values that the home screen does not show
/// itself (CAPE, inversion, low-level jet, polar vortex ...), each leading to the screen with the value.
struct AttentionCard: View {
    @ObservedObject private var store = GlossaryNotes.shared
    @Environment(\.openRoute) private var openRoute
    @State private var expanded = false

    /// Screen of the app that shows the value of a glossary id.
    static func destination(_ id: String) -> MoreDestination? {
        switch id {
        case "cape", "cin", "lifted_index", "scherung", "inversion", "grenzschicht", "llj", "nullgradgrenze",
             "schneefallgrenze", "warmschicht", "radiosonde":
            return .profil
        case "gwl", "wetterregime", "nao", "ao", "polarwirbel", "ssw":
            return .grosswetterlage
        case "frost", "bodenfrost", "glaette", "nebel":
            return .warnungen
        case "taupunkt", "spread", "beaufort", "boee", "luftdruck", "drucktendenz":
            return .messwerte
        default:
            return nil
        }
    }

    var body: some View {
        let notes = store.notes.filter { !NowDetailsCard.noteIds.contains($0.id) }
        if !notes.isEmpty {
            let shown = expanded ? notes : Array(notes.prefix(3))
            VStack(alignment: .leading, spacing: 8) {
                CardTitle("Gerade auffällig", systemImage: "lightbulb", trailing: notes.count > 1 ? "\(notes.count) Werte" : nil)
                ForEach(shown, id: \.self) { note in
                    HStack(alignment: .center, spacing: 4) {
                        NoteCallout(note: note)
                        if let destination = Self.destination(note.id) {
                            Button {
                                openRoute(.more(destination))
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .opacity(0.6)
                                    .frame(width: 26, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(destination.title) öffnen")
                        }
                    }
                }
                if notes.count > shown.count || expanded && notes.count > 3 {
                    Button(expanded ? "Weniger anzeigen" : "Alle \(notes.count) anzeigen") {
                        withAnimation(.snappy) { expanded.toggle() }
                    }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.plain)
                    .opacity(0.85)
                }
            }
            .card()
        }
    }
}
