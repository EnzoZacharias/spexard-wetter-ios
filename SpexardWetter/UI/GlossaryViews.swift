import SwiftUI

/// Small (i) next to a professional value: opens the glossary text of `id`. Hidden when the
/// glossary has no such entry (the app never invents an explanation).
struct InfoButton: View {
    let id: String
    var compact = false
    @ObservedObject private var glossary = Glossary.shared
    @State private var shown: GlossaryEntry?

    init(_ id: String, compact: Bool = false) {
        self.id = id
        self.compact = compact
    }

    var body: some View {
        if let entry = glossary.entry(id) {
            Button {
                shown = entry
            } label: {
                Image(systemName: "info.circle")
                    .font(compact ? .caption2 : .footnote)
                    .opacity(0.75)
                    .frame(minWidth: compact ? 20 : 24, minHeight: compact ? 18 : 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Was ist \(entry.begriff)?")
            .sheet(item: $shown) { entry in
                GlossarySheet(entry: entry)
            }
        }
    }
}

/// The whole entry: short line, explanation, usual values, meaning for Spexard, example.
struct GlossaryEntryView: View {
    let entry: GlossaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(entry.kurz)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            section("Was ist das?", entry.erklaerung, icon: "book")
            section("Typische Werte", entry.typisch, icon: "ruler")
            section("Für Spexard", entry.spexard, icon: "house")
            if let example = entry.beispiel, !example.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Beispiel", systemImage: "quote.bubble").font(.footnote.weight(.semibold)).opacity(0.8)
                    Text("„\(example)“")
                        .font(.callout.italic())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            section("Auffällig ab", entry.auffaelligAb, icon: "lightbulb")
            if let aliases = entry.aliase, !aliases.isEmpty {
                Text("Auch: \(aliases.joined(separator: ", "))").font(.caption).opacity(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section(_ title: String, _ text: String?, icon: String) -> some View {
        if let text, !text.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon).font(.footnote.weight(.semibold)).opacity(0.8)
                Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

struct GlossarySheet: View {
    let entry: GlossaryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                GlossaryEntryView(entry: entry).padding(20)
            }
            .navigationTitle(entry.begriff)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// "Was heißt das jetzt": the server's note for a conspicuous value, right at the value. Shown
/// only when the server sends one (its rules and thresholds decide, never the app).
struct NoteCallout: View {
    let text: String
    var title: String = "Was heißt das jetzt"
    /// Glossary entry behind the note (info button).
    var glossaryId: String?
    /// "achtung" for stronger notes (e.g. gusts, thunderstorms), else a calm hint.
    var level: String?
    /// "ICON-D2 · Sa 07.11." (where the value comes from and when it occurs).
    var caption: String?
    /// Two lines until tapped (next to charts, where the full text would push the chart away).
    var compact = false
    @State private var expanded = false

    private var tint: Color {
        switch level {
        case "achtung", "warnung", "warn", "hoch": return Color(red: 1.0, green: 0.62, blue: 0.25)
        default: return Color(red: 1.0, green: 0.84, blue: 0.35)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.footnote)
                .foregroundStyle(tint)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(text)
                    .font(.footnote)
                    .lineLimit(compact && !expanded ? 2 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                if let caption, !caption.isEmpty {
                    Text(caption).font(.caption2).opacity(0.75)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if compact { withAnimation(.snappy) { expanded.toggle() } }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(text)\(caption.map { ". \($0)" } ?? "")")
            Spacer(minLength: 0)
            if let glossaryId { InfoButton(glossaryId) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3).padding(.vertical, 6)
        }
    }
}

extension NoteCallout {
    init(note: GlossaryNote, compact: Bool = false) {
        self.init(
            text: note.text,
            title: note.titel ?? "Was heißt das jetzt",
            glossaryId: note.id,
            level: note.stufe,
            caption: [note.quelle, note.wann].compactMap { $0 }.filter { !$0.isEmpty && $0 != "jetzt" }.joined(separator: " · "),
            compact: compact
        )
    }
}

/// The server's current notes for these glossary ids (or of one day), stacked; nothing when no
/// value is conspicuous.
struct GlossaryNotesView: View {
    let ids: [String]
    var day: Date?
    var compact = false
    @ObservedObject private var store = GlossaryNotes.shared

    init(_ ids: [String], compact: Bool = false) {
        self.ids = ids
        self.compact = compact
    }

    /// The notes on the local weather of this day (any glossary id).
    init(day: Date) {
        self.ids = []
        self.day = day
    }

    var body: some View {
        let notes = day.map { store.notes(onDay: $0) } ?? store.notes(ids)
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(notes, id: \.self) { note in
                    NoteCallout(note: note, compact: compact)
                }
            }
        }
    }
}
