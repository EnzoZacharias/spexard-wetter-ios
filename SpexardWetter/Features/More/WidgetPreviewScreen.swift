import SwiftUI
import WidgetKit

/// The widgets of the app with the current data, plus how to add them.
struct WidgetPreviewScreen: View {
    @State private var snapshot: WidgetSnapshot?
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
                if LaunchArgs.option == "gross" {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    proxy.scrollTo("gross", anchor: .top)
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
        snapshot = await WidgetSnapshot.load()
        loaded = true
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
