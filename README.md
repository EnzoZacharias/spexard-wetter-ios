# Spexard Wetter – iPhone-App

Native SwiftUI-App für den eigenen Wetterserver
([Wetter-MCP v2](https://github.com/EnzoZacharias/wetter-mcp), läuft als Home-Assistant-App).
Die App zeigt nur, was der Server liefert (keine eigene Meteorologie, nur Darstellung):

- **Wetter**: amtliche DWD-Warnung als Banner, aktuelle Temperatur (eigener Außensensor vor der
  DWD-Station und dem Modell), Regen in den nächsten 2 Stunden (Radar-Nowcast), 24 Stunden mit
  Regen/Wind und Sonnenauf- und -untergang, Wetterbericht-Anriss, aktuelle Details, 16 Tage
  (Tippen öffnet den Tag mit allen Modellen und dem Ensemble)
- **Radar**: DWD-Radar und Nowcast als animierte Karte mit Legende, Umkreis-Satz, Regenrate unter
  dem Finger und „Radar am Standort“
- **Bericht**: Wetterbericht für heute, das Wochenende und die Woche
- **Mehr**: Karten (eigene ICON-D2-Karten für NRW), Warnungen & Gefahren, Messwerte, Meteogramm, Modellvergleich, Ensembles, Trend,
  Großwetterlage, Profil (Radiosonde und Höhenschnitt), Modellgüte, Server-Status
- **Widgets**: klein, mittel, groß, Sperrbildschirm (rechteckig, rund, einzeilig) und
  „Regen in 2 Stunden“
- Offline: die letzte Antwort jeder Seite bleibt gespeichert und erscheint mit ihrem Stand

Der Stand der Arbeit steht in [docs/ROADMAP.md](docs/ROADMAP.md).

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

Startargument `-mock` lädt die Beispieldaten aus `SpexardWetter/Resources/mock_*.json`
(erzeugt mit `python scripts/make_mocks.py <wetter-mcp>` aus den Fixtures der Webseite). Für die
Screenshots in CI: `-tab radar|bericht|mehr`, `-screen <seite>` (z. B. `messwerte`, `meteogramm`),
`-option <wert>` (z. B. `ecmwf`, `woche`), `-scrollDays`, `-showDay 2026-11-05`, `-radarFrame N`,
`-radarPoint`, `-scrollBottom`, `-mapFrame N` (Karten). Die Karten-Beispieldaten kommen aus einem echten
Lauf, den der Server-Code verarbeitet hat: `python scripts/make_map_mocks.py <karten.json> <Laufordner>`.
