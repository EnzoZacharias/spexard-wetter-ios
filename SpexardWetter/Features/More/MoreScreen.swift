import SwiftUI

/// Detail screens of the "Mehr" tab.
enum MoreDestination: String, Hashable, CaseIterable, Identifiable {
    case warnungen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warnungen: return "Warnungen & Gefahren"
        }
    }

    var subtitle: String {
        switch self {
        case .warnungen: return "Amtliche Warnungen des DWD"
        }
    }

    var systemImage: String {
        switch self {
        case .warnungen: return "exclamationmark.triangle.fill"
        }
    }
}

struct MoreScreen: View {
    let home: HomeModel
    @State private var path: [MoreDestination] = LaunchArgs.screen.flatMap(MoreDestination.init(rawValue:)).map { [$0] } ?? []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 0) {
                        ForEach(MoreDestination.allCases) { destination in
                            NavigationLink(value: destination) {
                                MoreRow(title: destination.title, subtitle: destination.subtitle, systemImage: destination.systemImage)
                            }
                            .buttonStyle(.plain)
                            if destination != MoreDestination.allCases.last {
                                Divider().overlay(.white.opacity(0.2)).padding(.leading, 52)
                            }
                        }
                    }
                    .card()

                    Button {
                        showSettings = true
                    } label: {
                        MoreRow(title: "Einstellungen", subtitle: "Server-Adresse, Version", systemImage: "gearshape.fill")
                    }
                    .buttonStyle(.plain)
                    .card()

                    StandFooter(date: nil, sources: "Daten: DWD, Open-Meteo.com (CC BY 4.0), Bright Sky")
                }
                .padding(16)
            }
            .screenBackground()
            .navigationTitle("Mehr")
            .navigationDestination(for: MoreDestination.self) { destination in
                switch destination {
                case .warnungen: WarningsScreen(home: home)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

struct MoreRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.18)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.caption).opacity(0.75)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).opacity(0.5)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Official warnings (full list) with pull to refresh.
struct WarningsScreen: View {
    let home: HomeModel
    @StateObject private var alerts = Loader<AlertsResponse>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if alerts.fromCache { OfflineBanner(date: alerts.date) }
                if let value = alerts.value {
                    WarningList(block: value.warnungen, reference: home.reference)
                } else if let error = alerts.error {
                    StateMessage(kind: .error, text: error) { await alerts.reload() }.card()
                } else {
                    StateMessage(kind: .loading).card()
                }
                StandFooter(date: alerts.date, fromCache: alerts.fromCache, sources: "Quelle: Deutscher Wetterdienst (DWD) via Bright Sky")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await alerts.reload()
        }
        .task { await alerts.loadIfNeeded(.alerts) }
        .screenBackground()
        .navigationTitle("Warnungen")
    }
}
