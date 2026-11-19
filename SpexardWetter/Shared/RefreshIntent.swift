import AppIntents
import SwiftUI
import WidgetKit

/// Loads every widget of the app again (the time in a widget is a button for it, iOS 17).
struct RefreshWeatherIntent: AppIntent {
    static var title: LocalizedStringResource = "Widgets aktualisieren"
    static var description = IntentDescription("Lädt die Werte aller Spexard-Wetter-Widgets neu vom Wetterserver.")
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// The time of the shown values with a small arrow: a tap asks the server again.
struct RefreshTimeButton: View {
    let text: String
    var font: Font = .caption2

    var body: some View {
        Button(intent: RefreshWeatherIntent()) {
            HStack(spacing: 3) {
                Text(text)
                Image(systemName: "arrow.clockwise").imageScale(.small)
            }
            .font(font)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(text), neu laden")
    }
}
