import AppIntents
import SwiftUI

/// Mehr → Siri & Kurzbefehle: what Siri understands without setup and what it answers right now
/// (the same sentences as `SiriAnswers`, from the same server answers).
struct SiriScreen: View {
    private struct Item: Identifiable {
        let id: String
        let title: String
        let icon: String
        let phrases: [String]
    }

    /// Mirrors `SpexardShortcuts` ("Spexard Wetter" is the app's name on the home screen).
    private static let items: [Item] = [
        Item(id: "garten", title: "Temperatur im Garten", icon: "thermometer.medium",
             phrases: ["Spexard Wetter Garten", "wie warm ist es im Garten bei Spexard Wetter?"]),
        Item(id: "regen", title: "Regen in 2 Stunden", icon: "cloud.rain",
             phrases: ["Spexard Wetter Regen", "regnet es gleich bei Spexard Wetter?"]),
        Item(id: "warnungen", title: "Amtliche Warnungen", icon: "exclamationmark.triangle",
             phrases: ["Spexard Wetter Warnungen", "gibt es eine Wetterwarnung bei Spexard Wetter?"]),
        Item(id: "wetter", title: "Wetter jetzt", icon: "cloud.sun",
             phrases: ["wie ist das Wetter bei Spexard Wetter?", "Wetter jetzt bei Spexard Wetter"]),
    ]

    @State private var answers: [String: String] = [:]
    @State private var date: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Diese Sätze kennt Siri ohne Einrichtung (Siri auf Deutsch). Siri fragt den Wetterserver, ohne die App zu öffnen; die Antworten stehen auch in der Kurzbefehle-App bereit, z. B. für eine Automation am Morgen.")
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
                    .card()
                ForEach(Self.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        CardTitle(item.title, systemImage: item.icon)
                        ForEach(item.phrases, id: \.self) { phrase in
                            Label("„Hey Siri, \(phrase)“", systemImage: "mic.fill")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        answerView(answers[item.id])
                    }
                    .card()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Eigene Sätze und Automationen: in der Kurzbefehle-App einen Kurzbefehl mit einer dieser Aktionen anlegen und ihm einen Namen geben, z. B. „Garten“.")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    ShortcutsLink()
                }
                .card()
                StandFooter(date: date, sources: "Antworten aus denselben Daten wie die App: Gartensensor, DWD-Radar, DWD-Warnungen")
            }
            .padding(16)
        }
        .refreshable {
            Haptics.armRefresh()
            await load()
        }
        .task { if answers.isEmpty { await load() } }
        .screenBackground()
        .navigationTitle("Siri & Kurzbefehle")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func answerView(_ answer: String?) -> some View {
        if let answer {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "waveform")
                    .font(.footnote)
                    .opacity(0.8)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Siri antwortet jetzt").font(.caption.weight(.bold)).opacity(0.8)
                    Text(answer).font(.footnote).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.10)))
            .accessibilityElement(children: .combine)
        } else {
            ProgressView().tint(.white).frame(maxWidth: .infinity)
        }
    }

    private func load() async {
        async let garden = SiriAnswers.loadGarden()
        async let rain = SiriAnswers.loadRain()
        async let warnings = SiriAnswers.loadWarnings()
        async let weather = SiriAnswers.loadWeather()
        let g = await garden
        let r = await rain
        let w = await warnings
        let n = await weather
        answers = ["garten": g, "regen": r, "warnungen": w, "wetter": n]
        date = Date()
    }
}
