import SwiftUI

struct HomeView: View {
    @State private var model = HomeModel()
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private static let scrollToDays = ProcessInfo.processInfo.arguments.contains("-scrollDays")

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        CurrentHeader(model: model)
                        if let error = model.errorText {
                            ErrorCard(text: error) { showSettings = true }
                        }
                        HourlyStrip(items: model.hourItems)
                        DailyList(items: model.days, range: model.daysRange)
                            .id("days")
                        Footer(lastUpdate: model.lastUpdate)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .foregroundStyle(.white)
                }
                .scrollIndicators(.hidden)
                .refreshable { await model.load() }
                .task {
                    if ServerSettings.current.isEmpty && !APIClient.isMock {
                        showSettings = true
                    }
                    await model.load()
                    if Self.scrollToDays {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        proxy.scrollTo("days", anchor: .top)
                    }
                }
            }
            .background(BackgroundGradient(night: model.isNight).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings, onDismiss: { Task { await model.load() } }) {
                SettingsView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            if let last = model.lastUpdate, Date().timeIntervalSince(last) < 300 { return }
            Task { await model.load() }
        }
    }
}

// MARK: - background

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
}

// MARK: - current

struct CurrentHeader: View {
    let model: HomeModel

    var body: some View {
        let temp = model.currentTemp
        let range = model.todayRange
        VStack(spacing: 4) {
            Text(model.locationLabel)
                .font(.title3.weight(.semibold))
                .padding(.top, 8)
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: WeatherSymbol.name(text: model.skyText, night: model.isNight))
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 54))
                Text(Fmt.temp(temp.value, decimals: 1))
                    .font(.system(size: 84, weight: .thin))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityLabel("Aktuell \(Fmt.temp(temp.value, decimals: 1))")
            }
            if let sky = model.skyText {
                Text(sky.prefix(1).uppercased() + sky.dropFirst())
                    .font(.title3)
            }
            if range.min != nil || range.max != nil {
                Text("Max \(Fmt.temp(range.max)) · Min \(Fmt.temp(range.min))")
                    .font(.headline)
                    .opacity(0.9)
            }
            Label(temp.sourceText, systemImage: temp.source == .local ? "sensor.fill" : "dot.radiowaves.left.and.right")
                .font(.footnote)
                .opacity(0.8)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}

struct ErrorCard: View {
    let text: String
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Daten nicht vollständig", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(text).font(.footnote)
            Button("Server-Adresse prüfen", action: openSettings)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.white)
        }
        .card()
    }
}

struct Footer: View {
    let lastUpdate: Date?

    var body: some View {
        VStack(spacing: 4) {
            if let lastUpdate {
                Text("Aktualisiert \(Fmt.time(lastUpdate)) Uhr")
            }
            Text("Daten: DWD, Open-Meteo.com (CC BY 4.0), Bright Sky")
        }
        .font(.caption2)
        .opacity(0.7)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
