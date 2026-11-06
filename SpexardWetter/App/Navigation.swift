import SwiftUI

/// Where a link of the server (a page of the website, "/meteogramm") leads in the app.
enum AppRoute: Hashable {
    case tab(AppTab)
    case more(MoreDestination)

    init?(href: String) {
        let path = href.split(separator: "?").first.map(String.init) ?? href
        switch path {
        case "/", "/uebersicht", "/vorhersage": self = .tab(.wetter)
        case "/radar": self = .tab(.radar)
        case "/wetterbericht": self = .tab(.bericht)
        default:
            guard let destination = MoreDestination.allCases.first(where: { $0.webPath == path }) else { return nil }
            self = .more(destination)
        }
    }
}

/// Opens a route (switches the tab, pushes the screen in "Mehr").
struct OpenRouteAction {
    let handler: (AppRoute) -> Void

    func callAsFunction(_ route: AppRoute) {
        handler(route)
    }
}

private struct OpenRouteKey: EnvironmentKey {
    static let defaultValue = OpenRouteAction { _ in }
}

extension EnvironmentValues {
    var openRoute: OpenRouteAction {
        get { self[OpenRouteKey.self] }
        set { self[OpenRouteKey.self] = newValue }
    }
}
