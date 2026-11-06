import SwiftUI

/// Mehr → Lexikon: every glossary term of the server, grouped by topic, with search. The reference
/// behind the info buttons and the inline notes.
struct LexikonScreen: View {
    @ObservedObject private var glossary = Glossary.shared
    @State private var query = LaunchArgs.value("-search") ?? ""
    /// `-entry cape` (screenshots) opens one entry at the start.
    @State private var opened: GlossaryEntry?

    private var groups: [(id: String, name: String, items: [GlossaryEntry])] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return glossary.groups }
        return glossary.groups.compactMap { group -> (id: String, name: String, items: [GlossaryEntry])? in
            let hits = group.items.filter { e in
                ([e.begriff, e.kurz, e.id] + (e.aliase ?? [])).contains { $0.lowercased().contains(q) }
            }
            if hits.isEmpty { return nil }
            return (id: group.id, name: group.name, items: hits)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if glossary.entries.isEmpty {
                    StateMessage(kind: .empty, text: "Das Lexikon ist noch leer.").card()
                } else if groups.isEmpty {
                    StateMessage(kind: .empty, text: "Kein Begriff passt zu „\(query)“.").card()
                }
                ForEach(groups, id: \.id) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.name)
                            .font(.footnote.weight(.semibold))
                            .textCase(.uppercase)
                            .opacity(0.75)
                            .padding(.leading, 4)
                            .accessibilityAddTraits(.isHeader)
                        VStack(spacing: 0) {
                            ForEach(group.items) { entry in
                                NavigationLink {
                                    LexikonEntryScreen(entry: entry)
                                } label: {
                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.begriff).font(.subheadline.weight(.semibold))
                                            Text(entry.kurz).font(.caption).opacity(0.8).lineLimit(2)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).opacity(0.5)
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                    .accessibilityElement(children: .combine)
                                }
                                .buttonStyle(.plain)
                                if entry.id != group.items.last?.id {
                                    Divider().overlay(.white.opacity(0.2))
                                }
                            }
                        }
                        .card()
                    }
                }
                StandFooter(date: nil, sources: glossary.fromServer ? "Texte vom Wetterserver" : "Mitgelieferte Texte des Wetterservers")
            }
            .padding(16)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Begriff suchen")
        .navigationDestination(item: $opened) { entry in
            LexikonEntryScreen(entry: entry)
        }
        .task {
            if let id = LaunchArgs.value("-entry"), opened == nil { opened = glossary.entry(id) }
            await glossary.refresh()
        }
        .screenBackground()
        .navigationTitle("Lexikon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LexikonEntryScreen: View {
    let entry: GlossaryEntry

    var body: some View {
        ScrollView {
            GlossaryEntryView(entry: entry)
                .card()
                .padding(16)
        }
        .screenBackground()
        .navigationTitle(entry.begriff)
        .navigationBarTitleDisplayMode(.inline)
    }
}
