import SwiftUI
import WidgetKit

/// The widgets of the app with the current data, plus how to add them.
struct WidgetPreviewScreen: View {
    @State private var snapshot: WidgetSnapshot?
    @State private var history: HistoryWidgetData?
    @State private var now: WeatherNow?
    @State private var loaded = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .padding(16)
            }
            .refreshable { await reload() }
            .task {
                if !loaded { await reload() }
                // screenshots: `-screen widgets -option gross` starts at the large widget
                if let target = LaunchArgs.option, ["gross", "historie", "messwert"].contains(target) {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .screenBackground()
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            section("Verlauf & Live · mittel") {
                liveWidget(.systemMedium, height: 170)
            }
            section("Verlauf & Live · groß") {
                liveWidget(.systemLarge, height: 382)
            }
            Text("Widget hinzufügen: Home-Bildschirm oder Sperrbildschirm lange drücken, „Bearbeiten“ und dann „Widget hinzufügen“ antippen, nach „Spexard Wetter“ suchen. Die Widgets holen ihre Daten alle 20 Minuten selbst vom Wetterserver.")
                .font(.footnote)
                .opacity(0.9)
                .card()

            if !loaded {
                StateMessage(kind: .loading).card()
            } else if snapshot == nil {
                StateMessage(kind: .error, text: "Keine Verbindung zum Wetterserver: die Widgets zeigen dann einen Hinweis.") {
                    await reload()
                }
                .card()
            }

            section("Klein") {
                systemWidget(.systemSmall, width: 170, height: 170)
            }
            section("Mittel") {
                systemWidget(.systemMedium, width: 364, height: 170)
            }
            section("Groß") {
                systemWidget(.systemLarge, width: 364, height: 382)
            }
            .id("gross")
            section("Historie Garten") {
                HStack(alignment: .top, spacing: 14) {
                    historyWidget(.systemSmall, width: 170, height: 170)
                    historyWidget(.accessoryRectangular, width: 160, height: 76)
                }
                historyWidget(.systemMedium, width: 364, height: 170)
            }
            .id("historie")
            section("Messwert (einstellbar)") {
                HStack(alignment: .top, spacing: 14) {
                    measurementWidget(.taupunkt)
                    measurementWidget(.boeen)
                }
                HStack(alignment: .top, spacing: 14) {
                    measurementAccessory(.luftdruck, family: .accessoryRectangular, width: 172, height: 76)
                    measurementAccessory(.feuchte, family: .accessoryCircular, width: 76, height: 76)
                }
                Text("Welcher Wert: Widget lange drücken, „Widget bearbeiten“ und die Messgröße wählen (Temperatur, Taupunkt, Luftfeuchte, Wind, Böen, Luftdruck, Regen der letzten Stunde, Sichtweite).")
                    .font(.caption)
                    .opacity(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id("messwert")
            section("Regen in 2 Stunden") {
                rainWidget()
                accessoryRain()
            }
            section("Sperrbildschirm") {
                HStack(alignment: .top, spacing: 14) {
                    accessory(.accessoryRectangular, width: 172, height: 76)
                    accessory(.accessoryCircular, width: 76, height: 76)
                }
                accessory(.accessoryInline, width: 250, height: 26)
            }
        }
    }

    private func reload() async {
        async let main = WidgetSnapshot.load()
        async let past = HistoryWidgetData.load()
        async let current: Fetched<WeatherNow> = APIClient().fetch(.now)
        snapshot = await main
        history = await past
        now = (try? await current)?.value
        loaded = true
    }

    private func measurementData(_ kind: MeasurementKind) -> MeasurementWidgetData? {
        now.flatMap { MeasurementWidgetData(kind, now: $0, offline: false) }
    }

    private func measurementWidget(_ kind: MeasurementKind) -> some View {
        MeasurementWidgetContent(family: .systemSmall, data: measurementData(kind), kind: kind, placeholder: !loaded)
            .padding(16)
            .frame(width: 170, height: 170)
            .background(BackgroundGradient(night: true))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25)))
    }

    private func measurementAccessory(_ kind: MeasurementKind, family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        MeasurementWidgetContent(family: family, data: measurementData(kind), kind: kind, placeholder: !loaded)
            .foregroundStyle(.white)
            .frame(width: width, height: height, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.45)))
    }

    @ViewBuilder
    private func historyWidget(_ family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        if family == .accessoryRectangular {
            HistoryWidgetContent(family: family, data: history, placeholder: !loaded)
                .foregroundStyle(.white)
                .frame(width: width, height: height, alignment: .leading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.45)))
        } else {
            HistoryWidgetContent(family: family, data: history, placeholder: !loaded)
                .padding(16)
                .frame(width: width, height: height)
                .background(BackgroundGradient(night: false))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25)))
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).textCase(.uppercase).opacity(0.8)
            content()
        }
    }

    private func systemWidget(_ family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        WidgetContent(family: family, snapshot: snapshot)
            .padding(16)
            .frame(width: width, height: height)
            .background(BackgroundGradient(night: snapshot?.night ?? false))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25)))
    }

    private func liveWidget(_ family: WidgetFamily, height: CGFloat) -> some View {
        LiveStripWidget(family: family, snapshot: snapshot, placeholder: !loaded)
            .padding(16)
            .frame(width: 364, height: height)
            .background(BackgroundGradient(night: snapshot?.night ?? false))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25)))
    }

    private func rainWidget() -> some View {
        RainWidgetContent(family: .systemMedium, snapshot: snapshot)
            .padding(16)
            .frame(width: 364, height: 170)
            .background(BackgroundGradient(night: snapshot?.night ?? false))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25)))
    }

    private func accessoryRain() -> some View {
        RainWidgetContent(family: .accessoryRectangular, snapshot: snapshot)
            .foregroundStyle(.white)
            .frame(width: 172, height: 76, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.45)))
    }

    private func accessory(_ family: WidgetFamily, width: CGFloat, height: CGFloat) -> some View {
        WidgetContent(family: family, snapshot: snapshot)
            .foregroundStyle(.white)
            .frame(width: width, height: height, alignment: .leading)
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.45)))
    }
}
