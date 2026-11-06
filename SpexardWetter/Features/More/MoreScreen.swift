import SwiftUI

/// Detail screens of the "Mehr" tab (in list order).
enum MoreDestination: String, Hashable, CaseIterable, Identifiable {
    case warnungen
    case messwerte
    case meteogramm
    case modelle
    case ensembles
    case trend
    case grosswetterlage
    case profil
    case modellguete
    case status
    case widgets

    var id: String { rawValue }

    private var info: (title: String, subtitle: String, icon: String, web: String?) {
        switch self {
        case .warnungen: return ("Warnungen & Gefahren", "Amtliche Warnungen des DWD", "exclamationmark.triangle.fill", "/gefahren")
        case .messwerte: return ("Messwerte", "Stationen der Umgebung, 24 bis 72 Stunden", "chart.xyaxis.line", "/messwerte")
        case .meteogramm: return ("Meteogramm", "Stunde für Stunde je Modell", "chart.bar.xaxis", "/meteogramm")
        case .modelle: return ("Modellvergleich", "ICON, ECMWF, GFS und UKMO nebeneinander", "square.stack.3d.up.fill", "/modelle")
        case .ensembles: return ("Ensembles", "Temperaturfahnen, Regenrisiko, Sicherheit je Tag", "point.3.filled.connected.trianglepath.dotted", "/ensembles")
        case .trend: return ("Trend", "Tag 8 bis 16 und die Wochen danach", "chart.line.uptrend.xyaxis", "/trend")
        case .grosswetterlage: return ("Großwetterlage", "Wetterlage, Regime, Polarwirbel, AO und NAO", "globe.europe.africa.fill", "/grosswetterlage")
        case .profil: return ("Profil", "Radiosonde: Temperatur über der Höhe", "arrow.up.and.down.text.horizontal", "/profil")
        case .modellguete: return ("Modellgüte", "Welches Modell lag zuletzt richtig?", "checkmark.seal.fill", "/verifikation")
        case .status: return ("Status", "Zustand des Wetterservers und der Quellen", "server.rack", "/status")
        case .widgets: return ("Widgets", "Vorschau für Home- und Sperrbildschirm", "rectangle.3.group.fill", nil)
        }
    }

    var title: String { info.title }
    var subtitle: String { info.subtitle }
    var systemImage: String { info.icon }
    /// Page of the website with the same content (for the links in the report).
    var webPath: String? { info.web }

    @MainActor @ViewBuilder
    func screen(home: HomeModel) -> some View {
        switch self {
        case .warnungen: WarningsScreen(home: home)
        case .messwerte: MeasurementsScreen()
        case .meteogramm: MeteogramScreen()
        case .modelle: ModelsScreen()
        case .ensembles: EnsemblesScreen()
        case .trend: TrendScreen()
        case .grosswetterlage: LargeScaleScreen()
        case .profil: ProfileScreen()
        case .modellguete: VerificationScreen()
        case .status: StatusScreen()
        case .widgets: WidgetPreviewScreen()
        }
    }
}

struct MoreScreen: View {
    let home: HomeModel
    @Binding var path: [MoreDestination]
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
                destination.screen(home: home)
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
