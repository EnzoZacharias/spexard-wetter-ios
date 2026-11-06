# Spexard Wetter – iPhone-App

Native SwiftUI-App für den eigenen Wetterserver
([Wetter-MCP v2](https://github.com/EnzoZacharias/wetter-mcp), läuft als Home-Assistant-App).
Die App zeigt nur an, was der Server liefert:
- aktuelle Temperatur, mit dem eigenen Außensensor vor der DWD-Station und dem Modell
- die nächsten 24 Stunden
- 16 Tage

Geplant: Radar, Wetterbericht, Warnungen und Widgets.

Die App enthält keine Standortdaten und keine Geheimnisse. Sie spricht nur mit der eingestellten
Server-Adresse.

## Bauen ohne Mac

GitHub Actions baut bei jedem Push auf `main` (macOS-Runner, Xcode, Projekt aus `project.yml`
per [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

1. Simulator-Build, danach Screenshots mit Beispieldaten (`-mock`): Artefakt `screenshots-and-logs`.
2. Unsignierte `SpexardWetter.ipa` für das iPhone: Release **latest**
   (`https://github.com/EnzoZacharias/spexard-wetter-ios/releases/latest/download/SpexardWetter.ipa`).

Die eingebaute Server-Adresse kommt aus der Repository-Variable `API_BASE_URL`. In der App lässt sie
sich jederzeit unter Einstellungen ändern.

## Installieren (kostenlos, ohne Entwicklerkonto)

Mit [AltStore](https://altstore.io) (AltServer auf einem Windows-PC, normale Apple-ID):

1. AltServer einrichten und AltStore aufs iPhone bringen (einmalig, per Kabel).
2. Auf dem iPhone den Entwicklermodus einschalten: Einstellungen → Datenschutz & Sicherheit.
3. Auf dem iPhone `SpexardWetter.ipa` aus dem Release laden → Teilen → AltStore.

Ohne Entwicklerkonto gilt die Signatur 7 Tage. AltStore verlängert sie automatisch, wenn iPhone und PC
mit AltServer im selben WLAN sind.

## Lokal entwickeln (mit Mac)

```bash
brew install xcodegen
xcodegen generate
open SpexardWetter.xcodeproj
```

Startargument `-mock` lädt die Beispieldaten aus `SpexardWetter/Resources/mock_*.json`.
