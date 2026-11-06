import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case wetter, radar, bericht, mehr
}

/// Launch arguments for the CI screenshots: `-mock`, `-tab radar`, `-screen messwerte`, `-scrollDays`.
enum LaunchArgs {
    static func value(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: name), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }

    static var tab: AppTab? { value("-tab").flatMap(AppTab.init(rawValue:)) }
    static var screen: String? { value("-screen") }
    static var option: String? { value("-option") }
}

struct RootView: View {
    @State private var tab: AppTab = LaunchArgs.tab ?? (LaunchArgs.screen != nil ? .mehr : .wetter)
    @State private var home = HomeModel()
    @State private var morePath: [MoreDestination] = LaunchArgs.screen.flatMap(MoreDestination.init(rawValue:)).map { [$0] } ?? []

    var body: some View {
        TabView(selection: $tab) {
            HomeView(model: home, openTab: { tab = $0 })
                .tabItem { Label("Wetter", systemImage: "cloud.sun.fill") }
                .tag(AppTab.wetter)
            RadarScreen()
                .tabItem { Label("Radar", systemImage: "map") }
                .tag(AppTab.radar)
            ReportScreen()
                .tabItem { Label("Bericht", systemImage: "newspaper") }
                .tag(AppTab.bericht)
            MoreScreen(home: home, path: $morePath)
                .tabItem { Label("Mehr", systemImage: "square.grid.2x2") }
                .tag(AppTab.mehr)
        }
        .tint(.white)
        .environment(\.isNight, home.isNight)
        .environment(\.openRoute, OpenRouteAction { route in
            switch route {
            case .tab(let target):
                tab = target
            case .more(let destination):
                morePath = [destination]
                tab = .mehr
            }
        })
        .environment(\.locale, Fmt.locale)
        .environment(\.timeZone, Fmt.zone)
        .environment(\.calendar, Fmt.calendar)
        .preferredColorScheme(.dark)
        .onChange(of: tab) { _, _ in Haptics.selection() }
    }
}
