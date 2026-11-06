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
- [x] Bericht-Tab: `/api/v1/wetterbericht?art=heute|wochenende|woche` mit Segmenten, Abschnitts-Chips,
      Kennzahlen, Temperaturkurve, DWD-Zitaten, Warum-Fragen, Fachteil und Stundentabelle;
      Links des Berichts öffnen die passenden App-Seiten (`-tab bericht -option woche`)
- [x] Widgets (WidgetKit-Extension, ohne App Group): klein, mittel, Sperrbildschirm rechteckig,
      rund und einzeilig; Aktualisierung alle 20 Minuten, Vorschau unter Mehr → Widgets (`-screen widgets`)
- [x] Mehr → Warnungen & Gefahren: amtliche Warnungen plus Gefahren-Zeitleiste (`/gefahren/matrix`)
- [x] Mehr → Messwerte: `/messwerte/verlauf?stunden=24|48|72`, heute bisher, Diagramme je Größe, Stationen
- [x] Mehr → Meteogramm: `/meteogramm/modell?modell=icon_d2|arome|ecmwf|gfs`, gestapelte Diagramme
      auf einer Zeitachse mit Nachtschattierung und Wettersymbolen
- [x] Mehr → Modellvergleich (`/modelle/stunden`): Kurven je Modell (abschaltbar), Spanne, Tageswerte
- [x] Mehr → Ensembles: Temperaturfahnen ECMWF/GEFS, Regenrisiko ICON-D2-EPS, Sicherheit je Tag
- [x] Mehr → Trend (`weather_trend`): Tag 8–16, Blöcke, Wochen 2–6
- [x] Mehr → Großwetterlage (`large_scale` + `/grosswetterlage/katalog`): GWL, Ensemble-Lagen, Regime,
      Polarwirbel mit Vorhersage, AO/NAO
- [x] Mehr → Profil (`/profil/sonde`): Temperatur/Taupunkt über der Höhe, Inversionen, Kennwerte, Vergleich ICON-D2
- [x] Mehr → Modellgüte (`/verifikation/auswertung?tage=7|30|90`): Aussagen, Fehler je Modell und Größe
- [x] Mehr → Status (`/status/uebersicht`): Ampel, Kontingent, Quellen, geplante Abrufe

## Als Nächstes

- [ ] Profil: Höhenschnitt `/profil/schnitt?modell=icon_d2|ecmwf` (Zeit-Höhen-Diagramm) fehlt noch
- [ ] Feinschliff: Pull to refresh überall, Haptik, leere Zustände

## Hinweise

- Kein Mac: jeder Push auf `main` baut in GitHub Actions, macht Screenshots (`-mock`) und
  veröffentlicht die unsignierte IPA als Release `latest`.
- Keine Adressen und keine genauen Koordinaten ins Repository (öffentlich).
