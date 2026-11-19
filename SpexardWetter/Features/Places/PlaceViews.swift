import SwiftUI

/// Button in the top bar of the Wetter tab: opens the place list.
struct PlaceButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                Text(title).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.18)))
        }
        .accessibilityLabel("Ort: \(title). Ort wechseln")
    }
}

/// The place list: home (all pages), the favourites of this device and the search of the server.
struct PlacePickerSheet: View {
    @ObservedObject private var store = PlaceStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = LaunchArgs.value("-placeSearch") ?? ""
    @State private var results: [Place] = []
    @State private var searching = false
    @State private var message: String?
    @State private var searched = false
    let homeLabel: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.select(nil)
                        dismiss()
                    } label: {
                        row(name: homeLabel, detail: "Heimat: alle Seiten, eigene Messwerte, Radar, Karten", icon: "house.fill", chosen: store.selected == nil)
                    }
                }
                if !store.favorites.isEmpty {
                    Section("Meine Orte") {
                        ForEach(store.favorites) { place in
                            Button {
                                store.select(place)
                                dismiss()
                            } label: {
                                row(name: place.name, detail: place.region ?? "", icon: "star.fill", chosen: store.selected?.id == place.id)
                            }
                        }
                        .onDelete { store.remove(at: $0) }
                    }
                }
                if searching {
                    Section { ProgressView("Suche …") }
                } else if let message {
                    Section { Text(message).font(.footnote) }
                } else if searched {
                    Section("Treffer") {
                        if results.isEmpty {
                            Text("Kein Ort in Deutschland passt zu „\(query)“.").font(.footnote)
                        }
                        ForEach(results) { place in
                            HStack {
                                Button {
                                    store.select(place)
                                    dismiss()
                                } label: {
                                    row(name: place.name, detail: [place.region, place.hoeheM.map { "\(Fmt.number($0, decimals: 0)) m" }].compactMap { $0 }.joined(separator: " · "), icon: "mappin", chosen: false)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    store.toggleFavorite(place)
                                } label: {
                                    Image(systemName: store.isFavorite(place) ? "star.fill" : "star")
                                        .foregroundStyle(.yellow)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(store.isFavorite(place) ? "Aus meinen Orten entfernen" : "Zu meinen Orten")
                            }
                        }
                    }
                }
                Section {
                    Text("Für andere Orte zeigt die App eine schlanke Ansicht: Modellwerte jetzt, 48 Stunden, 16 Tage und die amtlichen Warnungen der Gemeinde. Die Liste bleibt nur auf diesem iPhone. Radar, Bericht, Mehr, Widgets und Siri zeigen immer \(homeLabel).")
                        .font(.caption)
                    Text("Ortssuche: Open-Meteo Geocoding (GeoNames, CC BY 4.0)").font(.caption2).opacity(0.7)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Ort in Deutschland suchen")
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle("Orte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                // screenshots: `-placeSearch "Bad Salzuflen"` shows the hits at once
                if !query.isEmpty, !searched { await search() }
            }
        }
    }

    private func row(name: String, detail: String, icon: String, chosen: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(icon == "star.fill" ? Color.yellow : Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold))
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if chosen {
                Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    /// Asks the server only when the search is sent (each new text is one request upstream).
    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else {
            message = "Bitte mindestens zwei Buchstaben eingeben."
            return
        }
        searching = true
        message = nil
        defer { searching = false; searched = true }
        do {
            let answer: Fetched<PlaceSearchResponse> = try await APIClient().fetch(.placeSearch(text), timeout: 15)
            results = answer.value.treffer ?? []
        } catch {
            results = []
            message = error.localizedDescription
        }
    }
}

/// The Wetter tab for another place: model values now, warnings of its municipality, 48 hours and
/// 16 days (`/api/v1/ort`). The home place keeps the full start screen.
struct PlaceLiteScreen: View {
    let place: Place
    let homeLabel: String
    @StateObject private var loader = Loader<PlaceForecastResponse>()
    @ObservedObject private var store = PlaceStore.shared
    @State private var showPlaces = false

    /// "Now" of the answer (the example's time in the screenshots).
    private var reference: Date {
        APIClient.isMock ? (Fmt.parse(loader.value?.jetzt?.zeit) ?? Date()) : Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if loader.fromCache { OfflineBanner(date: loader.date) }
                    if let data = loader.value {
                        PlaceHeader(place: place, data: data)
                        PlaceWarnings(warnings: data.warnungen, area: data.ort?.warnzelle ?? place.name, reference: reference)
                        HourlyStrip(items: data.hourItems(), sunEvents: data.sunEvents(), title: "Nächste 48 Stunden", modes: [.regen, .wind])
                        let days = data.dayItems(reference: reference)
                        DailyList(items: days, range: Self.range(days))
                        ForEach(data.sourceErrors ?? [], id: \.self) { problem in
                            Label("\(problem.source ?? "Quelle"): \(problem.message ?? "nicht erreichbar")", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .opacity(0.8)
                        }
                    } else if let error = loader.error {
                        StateMessage(kind: .error, text: error) { await loader.reload() }.card()
                    } else {
                        StateMessage(kind: .loading, text: "Vorhersage für \(place.name) …").card()
                    }
                    Button {
                        store.select(nil)
                    } label: {
                        Label("Zurück zu \(homeLabel)", systemImage: "house.fill")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    StandFooter(
                        date: loader.date,
                        fromCache: loader.fromCache,
                        sources: "Vorhersage: Open-Meteo (best_match, CC BY 4.0) · Warnungen: Deutscher Wetterdienst via Bright Sky · Radar, Bericht und Mehr zeigen \(homeLabel)"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .foregroundStyle(.white)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                Haptics.armRefresh()
                await loader.load(place.forecastEndpoint)
            }
            .task(id: place.id) { await loader.loadIfNeeded(place.forecastEndpoint, maxAge: 600) }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PlaceButton(title: place.name) { showPlaces = true }
                }
            }
            .sheet(isPresented: $showPlaces) {
                PlacePickerSheet(homeLabel: homeLabel)
            }
        }
    }

    static func range(_ days: [DayItem]) -> ClosedRange<Double> {
        let values = days.flatMap { [$0.tmin, $0.tmax] }.compactMap { $0 }
        guard let lo = values.min(), let hi = values.max(), hi > lo else { return 0...1 }
        return lo...hi
    }
}

struct PlaceHeader: View {
    let place: Place
    let data: PlaceForecastResponse

    var body: some View {
        let now = data.jetzt
        let today = data.tage?.first
        VStack(spacing: 4) {
            // the searched name (the warn cell may name the larger municipality around it)
            Text(place.name)
                .font(.title3.weight(.semibold))
                .padding(.top, 8)
            if let region = place.region ?? [data.ort?.kreis, data.ort?.land].compactMap({ $0 }).joined(separator: ", ").nilIfEmpty {
                Text(region).font(.caption).opacity(0.8)
            }
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: WeatherSymbol.name(code: now?.wetterCode, night: now?.istTag == false))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 54))
                    .accessibilityHidden(true)
                Text(Fmt.temp(now?.temperaturC, decimals: 1))
                    .font(.system(size: 76, weight: .thin))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            if let text = now?.wetter {
                Text(text.prefix(1).uppercased() + text.dropFirst()).font(.title3)
            }
            if let today, today.maxC != nil || today.minC != nil {
                Text("Max \(Fmt.temp(today.maxC)) · Min \(Fmt.temp(today.minC))").font(.headline)
            }
            HStack(spacing: 14) {
                if let wind = now?.windKmh {
                    Label(Fmt.wind(wind) + (now?.windRichtungGrad.map { " aus " + Fmt.compass($0) } ?? ""), systemImage: "wind")
                }
                if let gust = now?.boeenKmh {
                    Label("Böen \(Fmt.wind(gust))", systemImage: "tornado")
                }
            }
            .font(.footnote)
            .opacity(0.9)
            Text("Modellwert für \(Fmt.time(Fmt.parse(now?.zeit))) Uhr, keine Messung" + (data.ort?.hoeheM.map { " · Modellhöhe \(Fmt.number($0, decimals: 0)) m" } ?? ""))
                .font(.caption2)
                .opacity(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The DWD warnings of the place's municipality, or the calm state.
struct PlaceWarnings: View {
    let warnings: [DwdWarning]?
    let area: String
    let reference: Date

    var body: some View {
        if let warnings {
            if warnings.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill").font(.title3).foregroundStyle(.green, .white)
                    Text("Keine amtliche Warnung des DWD für \(area).").font(.footnote)
                    Spacer(minLength: 0)
                }
                .card()
            } else {
                VStack(spacing: 12) {
                    ForEach(warnings) { warning in
                        WarningCard(warning: warning, pre: false, reference: reference)
                    }
                }
            }
        } else {
            Label("Die Warnungen für \(area) sind gerade nicht abrufbar.", systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        }
    }
}

extension String {
    /// nil for an empty string (optional chaining in views).
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
