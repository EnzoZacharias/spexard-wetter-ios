import Foundation
import SwiftUI

// MARK: - /api/v1/glossar

/// One term of the server's glossary (single source of truth in wetter-mcp
/// `src/wetter_mcp/web/glossary`): what it is, usual values, what it means for Spexard, an example.
struct GlossaryEntry: Decodable, Identifiable, Hashable {
    let id: String
    let begriff: String
    let kategorie: String?
    let kategorieName: String?
    /// One line for a tooltip.
    let kurz: String
    let erklaerung: String?
    let typisch: String?
    let spexard: String?
    let beispiel: String?
    let einheit: String?
    let aliase: [String]?
    /// When the server shows a note for this value ("CAPE ab 100 J/kg ..."), nil = never.
    let auffaelligAb: String?
}

/// The glossary answer: the entries plus the category names.
struct GlossaryResponse: Decodable {
    let entries: [GlossaryEntry]
    let categories: [String: String]

    private enum Keys: String, CodingKey {
        case eintraege, entries, begriffe, kategorien, categories
    }

    init(from decoder: Decoder) throws {
        if let list = try? decoder.singleValueContainer().decode([GlossaryEntry].self) {
            entries = list
            categories = [:]
            return
        }
        let c = try decoder.container(keyedBy: Keys.self)
        entries = (try? c.decode([GlossaryEntry].self, forKey: .eintraege))
            ?? (try? c.decode([GlossaryEntry].self, forKey: .entries))
            ?? (try? c.decode([GlossaryEntry].self, forKey: .begriffe))
            ?? []
        if let map = try? c.decode([String: String].self, forKey: .kategorien) {
            categories = map
        } else if let map = try? c.decode([String: String].self, forKey: .categories) {
            categories = map
        } else {
            categories = [:]
        }
    }
}

extension Endpoint {
    /// The bundled copy `glossar.json` is also the mock answer.
    static let glossary = Endpoint(path: "/api/v1/glossar", mock: "glossar")
}

/// The glossary of the app: the bundled copy at once (offline), replaced by the server's answer
/// once per start. The app never writes its own texts: a missing id shows no info button.
@MainActor
final class Glossary: ObservableObject {
    static let shared = Glossary()

    @Published private(set) var entries: [GlossaryEntry] = []
    @Published private(set) var categoryNames: [String: String] = [:]
    @Published private(set) var fromServer = false
    private var byId: [String: GlossaryEntry] = [:]
    private var loading = false

    private init() {
        if let url = Bundle.main.url(forResource: "glossar", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bundled = try? APIClient.decode(data, as: GlossaryResponse.self) {
            apply(bundled)
        }
    }

    func entry(_ id: String) -> GlossaryEntry? { byId[id] }

    /// Entries grouped by category in the server's order.
    var groups: [(id: String, name: String, items: [GlossaryEntry])] {
        var order: [String] = []
        var items: [String: [GlossaryEntry]] = [:]
        for e in entries {
            let key = e.kategorie ?? "sonstiges"
            if items[key] == nil { order.append(key) }
            items[key, default: []].append(e)
        }
        return order.map { key -> (id: String, name: String, items: [GlossaryEntry]) in
            let name = categoryNames[key] ?? items[key]?.first?.kategorieName ?? key.capitalized
            return (id: key, name: name, items: items[key] ?? [])
        }
    }

    /// Asks the server once per start (and again after a failure).
    func refresh() async {
        guard !fromServer, !loading else { return }
        loading = true
        defer { loading = false }
        guard let result: Fetched<GlossaryResponse> = try? await APIClient().fetch(.glossary),
              !result.value.entries.isEmpty else { return }
        apply(result.value)
        fromServer = !result.fromCache && !APIClient.isMock
    }

    private func apply(_ response: GlossaryResponse) {
        entries = response.entries
        categoryNames = response.categories
        byId = Dictionary(response.entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

// MARK: - /api/v1/glossar/hinweise

/// A value that is conspicuous right now, with the server's "Was heißt das jetzt" sentence. The
/// server's rules and thresholds decide (docs/THRESHOLDS.md in wetter-mcp), never the app.
struct GlossaryNote: Decodable, Hashable, Identifiable {
    /// Glossary entry of the value.
    let id: String
    /// "hinweis" or "achtung".
    let stufe: String?
    let text: String
    @Lenient var wert: Double?
    let einheit: String?
    /// When the value occurs ("jetzt", "Sa 07.11.", "Do 05.11. 05–06 Uhr").
    let wann: String?
    /// Model or station of the value.
    let quelle: String?
    /// Field in the server's data the note belongs to ("boundary_layer.days[0].icon_d2.cape_max_j_kg").
    let bezug: String?
    let begriff: String?
    let titel: String?

    static func == (a: GlossaryNote, b: GlossaryNote) -> Bool { a.id == b.id && a.text == b.text && a.bezug == b.bezug }
    func hash(into h: inout Hasher) { h.combine(id); h.combine(bezug) }

    var isAlert: Bool { stufe == "achtung" }
}

struct GlossaryNotesResponse: Decodable {
    let generatedAt: String?
    let hinweise: [GlossaryNote]
}

extension Endpoint {
    static let glossaryNotes = Endpoint(path: "/api/v1/glossar/hinweise", mock: "mock_glossar_hinweise")
}

/// The notes of the moment, shared by all screens (asked again after 10 minutes). A stored answer
/// older than three hours is not shown: an old frost note must not appear as if it were current.
@MainActor
final class GlossaryNotes: ObservableObject {
    static let shared = GlossaryNotes()

    @Published private(set) var notes: [GlossaryNote] = []
    @Published private(set) var date: Date?
    private var loading = false

    private init() {}

    func refresh(maxAge: TimeInterval = 600) async {
        if let date, Date().timeIntervalSince(date) < maxAge { return }
        guard !loading else { return }
        loading = true
        defer { loading = false }
        guard let result: Fetched<GlossaryNotesResponse> = try? await APIClient().fetch(.glossaryNotes) else { return }
        if result.fromCache, Date().timeIntervalSince(result.date) > 3 * 3600 {
            notes = []
        } else {
            notes = result.value.hinweise
        }
        date = result.fromCache ? nil : result.date
    }

    /// The notes of these glossary ids, in the given order.
    func notes(_ ids: [String]) -> [GlossaryNote] {
        ids.flatMap { id in notes.filter { $0.id == id } }
    }
}
