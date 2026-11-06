# Roadmap

Checkliste für den Ausbau der App (Stand wird mit jedem Push nachgezogen). Die App zeigt nur, was
der Wetterserver liefert; Beispieldaten für `-mock` kommen aus `wetter-mcp/web/fixtures`
(`python scripts/make_mocks.py <wetter-mcp>`, danach Datenschutz-Prüfung mit
`privacy_problems()` aus `web/scripts/record_fixtures.py`).

## Erledigt

- [x] Grundgerüst: aktuelle Temperatur (eigener Sensor > DWD-Station > Modell), 24 Stunden, 16 Tage
- [x] Tab-Leiste: Wetter, Radar, Bericht, Mehr (Startargumente `-tab <name>`, `-screen <name>`)
- [x] Startseite: Banner mit amtlicher DWD-Warnung (`weather_alerts`), Blatt mit allen Warnungen
- [x] Startseite: Regen in den nächsten 2 Stunden (`rain_nowcast`, Satz + 5-Minuten-Balken)
- [x] Mehr → Warnungen (Liste aller Warnungen und Vorabinformationen)
- [x] Letzte Antwort je Pfad im Cache, offline mit „Gespeicherter Stand“
- [x] Radar-Tab: `/api/v1/radar/bilder` (RLE-Klassen) als MapKit-Overlay, Abspielen/Regler,
      „Radar HH:MM“ / „Prognose HH:MM“, Legende in mm/h, 1-km-Kreis am Standort, Ringe 25/50/100 km,
      Umkreis-Satz und Kennzahlen des gezeigten Bilds (`-tab radar`, `-radarFrame N`)

## Als Nächstes

- [ ] Bericht-Tab: `/api/v1/wetterbericht?art=heute|wochenende|woche`
- [ ] Widgets (klein, mittel, Sperrbildschirm)
- [ ] Mehr: Gefahren-Matrix, Messwerte, Meteogramm
- [ ] Mehr: Modellvergleich, Ensembles, Trend, Großwetterlage, Profil, Modellgüte, Status
- [ ] Feinschliff: Pull to refresh überall, Haptik, leere Zustände

## Hinweise

- Kein Mac: jeder Push auf `main` baut in GitHub Actions, macht Screenshots (`-mock`) und
  veröffentlicht die unsignierte IPA als Release `latest`.
- Keine Adressen und keine genauen Koordinaten ins Repository (öffentlich).
