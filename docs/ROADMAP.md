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
- [x] Profil: Höhenschnitt `/profil/schnitt?modell=icon_d2|ecmwf` (Temperatur über Zeit und Höhe,
      0-°C-Grenze, Grenzschicht, Wolkenbasis), `-screen profil -option icon_d2`
- [x] Startseite: „Jetzt im Detail“ (Wind, Feuchte, Taupunkt, Druck, Wolken, Sicht, Regen, Sonne),
      Umkreis-Satz aus `/radar/umkreis`, Wetterbericht-Anriss, Tagesdetail per Tipp (`-showDay JJJJ-MM-TT`)
- [x] Feinschliff: Pull to refresh auf allen Listen-Seiten (Radar: Knopf + alle 5 Minuten), Haptik
      (Aktualisierung, Tabwechsel, Abspielen), leere Zustände, „kein Niederschlag“ in trockenen Diagrammen,
      VoiceOver-Texte für Stunden, Tage, Diagramme und Karte, Offline-Speicher in den Einstellungen
- [x] Radar: Bilder direkt aus den Lauflängen gemalt (nur nasse Pixel), Apple-Karten-Logo bleibt sichtbar,
      Tipp auf die Karte zeigt die Regenrate an der Stelle (Klasse des gezeigten Bilds) und die Entfernung
- [x] Widgets: Tipp öffnet Warnungen (bei Warnung), Radar (bei Regen) oder die Startseite
      (URL-Schema `spexardwetter://<tab oder seite>`); Messzeit im mittleren Widget
- [x] Zweites Widget „Regen in 2 Stunden“ (mittel und Sperrbildschirm): Nowcast-Satz und 5-Minuten-Balken
- [x] Großes Widget (aktuell, nächste Stunden, 6 Tage mit Temperaturbalken); rundes Sperrbildschirm-Widget
      als Skala zwischen Tiefst- und Höchstwert von heute

- [x] Startseite verlinkt weiter: aktuelle Werte → Messwerte, 24 Stunden → Meteogramm, Tage → Trend;
      Mehr-Liste nach Themen gegliedert

- [x] Offline: gespeicherte Antworten erscheinen sofort beim Start (mit ihrem Stand), der Server wird
      danach gefragt; abgelaufene Warnungen aus dem Speicher zeigen kein Banner; Widget-Galerie mit Platzhalter
- [x] Bericht teilen (Text), Gefahren-Zeitleiste ohne Stundenfugen
- [x] 24-Stunden-Leiste: Umschalter Regen (Risiko + Menge) / Wind (Richtungspfeil, Stärke, Böen),
      Sonnenauf- und -untergang zwischen den Stunden

- [x] Radar → „Radar am Standort“ (`rain_nowcast?detail=full`): Standort, ±1 km, ±3 km, Regenphasen,
      Radar gegen ICON-D2 je 15 Minuten (`-tab radar -radarPoint`)
- [x] CI: neuere Pushes ersetzen laufende Builds (concurrency)

- [x] Widget „Verlauf & Live“ (mittel, groß): Messwerte jetzt (Temperatur Sensor > Station > Modell mit
      Quelle und Zeit, Taupunkt, Feuchte, Wind mit Richtung, Böen, Luftdruck, Regen der letzten Stunde,
      Stationen) und 3-Stunden-Spalten aus `/vorhersage/stunden`: Symbol mit Nachtvariante,
      Temperaturkurve, Regen, Wind- und Böenzeile in Beaufort-Farben, Richtungspfeile, dunkle Nachtspalten,
      Wochentag beim Tageswechsel; Tipp öffnet das Meteogramm. Groß: höhere Kurve, Regenzeile immer
      sichtbar (0 = trocken), Regenrisiko-Zeile, Legende passend zu den Zeilen

- [x] `mock_hours` aus dem vollen Fixture `vorhersage__stunden` (Taupunkt, Bewölkung, Modellspanne,
      Sonnenminuten, Basis kurzfrist/global); Verlauf-Widget mit gestrichelter Taupunktlinie und
      Wolkenzeile (groß), Regen/Böen der Spalte = die 3 Stunden danach (Werte gelten für die Stunde davor);
      24-Stunden-Leiste mit Modus „Luft“ (Taupunkt, Bewölkung), Tagesdetail mit Taupunkt und Bewölkung

- [x] Regen-Testszenario nur für Screenshots: `-mock -scenario regen` liest
      `mock_*_szenario_regen.json` (ausgedachte Werte aus `scripts/make_rain_scenario.py`: Regenband im
      Radar, nasser Nowcast, nasse Abendstunden); ohne `-mock` nie benutzt

- [x] Mehr → Karten (`/api/v1/karten` + `/karten/bild`): eigene ICON-D2-Karten für NRW als MapKit-Bild,
      Ebenen-Chips (Niederschlag 1 h / 3 h / seit Laufbeginn als eine Wahl), Zeitregler mit Abspielen,
      Lauf und Gültigkeitszeit, Legende mit den Stufen des Servers, Wert am Standort und höchster Wert im
      Ausschnitt, Tipp auf die Karte nennt die Farbstufe; Knopf im Radar-Tab. Beispieldaten aus einem echten
      Lauf (18 UTC vom 6.11., +0 bis +12 h) mit `scripts/make_map_mocks.py` (`-screen karten -option boeen -mapFrame 1`);
      Satz je Ebene, Orte und Marker (▲/▼) des größten und kleinsten Werts aus dem Katalog
- [x] Lernen: Texte aus `/api/v1/glossar` (mitgelieferte Kopie `Resources/glossar.json` für offline), kleiner
      (i)-Knopf an den Profi-Werten (Startseite, Profil, Großwetterlage, Messwerte, Ensembles, Trend, Modellgüte,
      Modellvergleich, Gefahren, Karten), Hinweise „Was heißt das jetzt“ aus `/api/v1/glossar/hinweise` direkt am
      Wert und nur, wenn der Server einen Wert auffällig findet (Schwellen nur auf dem Server); Startseite
      „Gerade auffällig“ mit Sprung zur passenden Seite; Mehr → Lexikon mit Suche (`-screen lexikon -entry cape`)

- [x] Verlauf-Widget: das Spalten-Symbol beschreibt dieselben 3 Stunden wie die Regenzeile (Nebel, Regen,
      Schnee oder Gewitter einer dieser Stunden gewinnt, sonst die mittlere Stunde)

- [x] Hinweise auch an den Meteogramm-Diagrammen (Temperatur: Frost, Bodenfrost, Glätte, Nebel; Wind: Böen, LLJ;
      Wolken: Inversion; Druck: Drucktendenz; CAPE: CAPE, LI), im Tagesdetail (Hinweise, deren `wann` den Tag nennt,
      ohne Großwetterlage), beim Trend (Polarwirbel, NAO, AO) und auf den Karten (Glossar-Ids der Ebene aus dem Katalog);
      großes Widget mit einer Hinweis-Zeile (stärkere zuerst, „+N“ für weitere), Vorschau `-screen widgets -option gross`
- [x] Mehr → Historie (`/api/v1/historie?zeitraum=tage|wochen|monate|jahre`): heute bisher im Garten, Satz zur
      Abweichung vom Normal, Tiefst-bis-Höchst-Balken mit dem Normal 1991–2020 dahinter, Zeitraum-Liste mit Mittel,
      Abweichung und Kenntagen, Rekorde Garten und Station, DWD-Station mit Niederschlag, Böe, Schnee, Bodenfrost,
      Garten gegen Station. Beispieldaten aus dem Endpunkt-Code von v2 (53507af) mit den echten Stundenwerten des
      Gartensensors seit 31.10. und den echten DWD-KL-Zips (`-screen historie -option monate`); Kenntage als
      Lexikon-Chips
- [x] Regen-Szenario auch in Meteogramm (alle vier Modelle), Modellvergleich (`-option precip`) und Regen-Ensemble
      (ICON-D2-EPS, `-screen ensembles -option regen`): dieselben ausgedachten Abendstunden, je Modell anders stark
- [x] Modellvergleich: (i) je Größe und Hinweise am Diagramm (Frost, LLJ, Böen, Inversion/Nebel); Hinweise unter
      Diagrammen zweizeilig, Tipp zeigt den ganzen Text

## Als Nächstes

- [ ] PR #1 (`wip-lexikon-hinweise`) nach `main` mergen: das Mergen ohne Review hat der Agent nicht selbst gemacht;
      erst danach gibt es eine neue IPA unter „latest“. Gebaut und geprüft bis 0d7ff76 (Lexikon, Hinweise, Karten,
      Widget-Zeile); Historie, Regen-Szenario, Historie-Widget kompilierten im Simulator-Build, ihre Screenshots
      (`historie`, `historie-monate`, `regen-meteogramm`, `regen-modelle`, `regen-ensembles`, `widgets-historie`)
      noch ansehen
- [ ] Widget „Historie Garten“ (klein, mittel, Sperrbildschirm; `/api/v1/historie?zeitraum=monate`, alle 30 Minuten)
      auf dem Gerät prüfen
- [ ] Historie: sobald der Pi `/api/v1/historie` hat, die echte Antwort mit den Beispieldaten vergleichen;
      Historie-Widget ist da (siehe oben)
- [ ] Profi-Daten, sobald der Server sie hat: Pollen, UV, Luftqualität, Sonne/Mond (je mit Lexikon-Eintrag)
- [ ] Widgets auf einem echten Gerät prüfen (Platzbedarf, Aktualisierung, Tippziele)
- [ ] Offline-Verhalten auf dem Gerät prüfen (Server nicht erreichbar)

## Hinweise

- Kein Mac: jeder Push auf `main` baut in GitHub Actions, macht Screenshots (`-mock`) und
  veröffentlicht die unsignierte IPA als Release `latest`.
- Keine Adressen und keine genauen Koordinaten ins Repository (öffentlich).
