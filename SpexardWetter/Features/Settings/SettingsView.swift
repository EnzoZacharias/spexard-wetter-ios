import SwiftUI

struct SettingsView: View {
    @AppStorage(ServerSettings.storageKey) private var serverURL = ""
    @Environment(\.dismiss) private var dismiss
    @State private var testResult: String?
    @State private var testing = false
    @State private var cacheBytes = ResponseCache.size

    private var cacheText: String {
        cacheBytes < 1_000_000
            ? Fmt.number(Double(cacheBytes) / 1000, decimals: 0) + " kB"
            : Fmt.number(Double(cacheBytes) / 1_000_000, decimals: 1) + " MB"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://homeassistant.local:8080", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Text("Verbindung testen")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(testing)
                    if let testResult {
                        Text(testResult).font(.footnote)
                    }
                } header: {
                    Text("Wetterserver")
                } footer: {
                    Text(footerText)
                }

                Section {
                    LabeledContent("Gespeichert", value: cacheText)
                    Button("Gespeicherte Antworten löschen", role: .destructive) {
                        ResponseCache.clear()
                        cacheBytes = ResponseCache.size
                    }
                    .disabled(cacheBytes == 0)
                } header: {
                    Text("Offline")
                } footer: {
                    Text("Die App merkt sich die letzte Antwort jeder Seite und zeigt sie ohne Verbindung mit ihrem Stand an.")
                }

                Section("Über die App") {
                    LabeledContent("Version", value: version)
                    Text("Spexard Wetter zeigt die Daten deines eigenen Wetterservers: DWD (Warnungen, Messungen, MOSMIX, Radar), Open-Meteo.com (Modelle, CC BY 4.0) und Bright Sky.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        serverURL = ServerSettings.normalized(serverURL)
                        dismiss()
                    }
                }
            }
        }
    }

    private var footerText: String {
        let builtIn = ServerSettings.builtIn
        let base = "Adresse des Wetterservers, z. B. die Home-Assistant-App im Heimnetz oder die Tailscale-Adresse für unterwegs."
        return builtIn.isEmpty ? base : base + " Leer lassen = eingebaute Adresse (\(builtIn))."
    }

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    @MainActor
    private func test() async {
        testing = true
        defer { testing = false }
        let address = ServerSettings.normalized(serverURL.isEmpty ? ServerSettings.builtIn : serverURL)
        do {
            let now = try await APIClient(baseURL: address).now()
            let t = now.localSensor?.temperatureC ?? now.now?.temperatureC?.measured ?? now.now?.temperatureC?.model
            testResult = "Verbunden mit \(now.location?.label ?? "Server"): \(Fmt.temp(t, decimals: 1))"
        } catch {
            testResult = "Keine Verbindung: \(error.localizedDescription)"
        }
    }
}
