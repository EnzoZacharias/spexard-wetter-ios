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

- [x] PR #1 gemergt (fd16a0a, Build 33 = IPA „latest“); Screenshots von Historie, Regen-Szenario und
      Historie-Widget angesehen

### Nacht 19./20.11.

- [x] Feinschliff Historie: Balken von kalt (unten) nach warm (oben) eingefärbt, Legende passend dazu; bei wenigen
      Zeiträumen (2 Monate, 3 Jahre) schmale Balken und jede Beschriftung mittig unter dem Balken („Okt“ fehlte);
      „Was heißt das jetzt“ unter „Heute bisher“ nur noch für Hinweise, die heute betreffen
- [x] Historie-Widget mittel: größere Werte, Monat mit Mittel und Normal („Ø 7,1°, Normal 8,0° (−0,9 K)“)
- [x] Lexikon: Titel nur der Kurzname („CAPE“), der ganze Begriff steht als Überschrift im Text
- [x] Diagramme: keine Punktreihe mehr auf der Nulllinie (Modellvergleich „höchster“, Regen-Ensemble
      „stärkster Lauf“, Böen); Punkt-Reihen in der Legende als Punkt
- [x] CI: Aufwärm-Start vor dem ersten Screenshot (Systemmitteilung verdeckte die Warnung)
- [x] Siri & Kurzbefehle (App Intents, ohne Entwicklerkonto): „Spexard Wetter Garten“ (Gartensensor jetzt, heute
      Tiefst/Höchst), „… Regen“ (Nowcast-Satz), „… Warnungen“ (DWD, Stufe, bis wann), „Wie ist das Wetter bei Spexard
      Wetter?“; Antworten mit Stand, offline mit Hinweis; als Aktionen in der Kurzbefehle-App mit Text als Ergebnis;
      Mehr → Siri & Kurzbefehle zeigt Sätze und aktuelle Antworten (`-screen siri`); Entwicklungssprache Deutsch;
      CI schreibt die erkannten Sätze nach `build-appintents.log`
- [x] Interaktive Widgets: Uhrzeit in Mittel/Groß, „Verlauf & Live“ und Historie ist ein Knopf zum Neuladen
- [x] Messwerte: Diagramme fehlten (die Schlüssel der Stationsreihen kommen je nach iOS-Version mit oder ohne
      Umbenennung an); jetzt werden beide Schreibweisen gesucht
- [x] Widget „Messwert“ auch mit Luftqualität (UBA-Index), Pollen heute (stärkste Art und weitere), UV-Index heute
      (und morgen) und Mond (Beleuchtung, Phase) aus `/api/v1/umwelt`; Siri „Spexard Wetter Pollen“ / „Wie ist die Luft
      bei Spexard Wetter?“ sagt Luft, Pollen, UV, Sonne und Mond; bei altem Server sagt Siri, dass er ein Update braucht
- [x] Andere Orte (`/api/v1/orte/suche`, `/api/v1/ort`): Knopf „Orte“ oben links im Wetter-Tab, Liste mit Heimat,
      „Meine Orte“ (nur UserDefaults, Wischen zum Löschen) und Suche erst beim Absenden (Stern = merken); ein gewählter
      Ort ersetzt den Wetter-Tab durch die Lite-Ansicht: Modellwert der laufenden Stunde (ausdrücklich keine Messung,
      mit Modellhöhe), Warnungen der Gemeinde (DWD via Bright Sky), 48 Stunden (Regen/Wind), 16 Tage, „Zurück zu Spexard“;
      Widgets und Siri bleiben bei Spexard; Beispieldaten aus den echten Fixtures (Bad Salzuflen), `-place`, `-placeSearch`
- [x] Umwelt & Himmel (`/api/v1/umwelt`, Mehr → Umwelt & Himmel und Karte auf der Startseite): Sonne mit Tagesbogen,
      Tageslänge und Änderung zu gestern, bürgerlicher Dämmerung, Höchststand und 7 Tagen; Mond mit Phase (Symbol),
      Beleuchtung, Alter, Auf-/Untergang in Zeitfolge und nächsten Hauptphasen; Luftqualität (UBA-Index in UBA-Farben,
      Schadstoffe mit Klasse, 24-Stunden-Diagramm); Pollenflug (nur fliegende Arten als Tabelle heute/morgen/Tag 3,
      sonst „keine Belastung“) und UV-Index (WHO-Farben); Hinweise des Servers direkt an der Karte; Lexikon-Knöpfe
      (`pollenflug`, `uv_index`, `luftqualitaet`, `feinstaub`, `ozon`, `stickstoffdioxid`, `tageslaenge`, `daemmerung`,
      `sonnenhoehe`, `mondphase`); „Gerade auffällig“ springt zu Umwelt; Beispieldaten aus dem echten Endpunkt-Code
      (`mock_umwelt`), Testszenario `-scenario belastung` mit ausgedachten Werten
- [x] Neues Widget „Messwert“ (einstellbar per App Intent, neue Art `SpexardMesswert`): klein, Sperrbildschirm rund,
      rechteckig und einzeilig; Wert der DWD-Station (Böen: stärkste der letzten Stunde), Station, Uhrzeit, Modellwert
      ICON-D2 daneben, Zusatz (Taupunkt: Spread, Wind/Böen: Richtung und Beaufort); Vorschau `-screen widgets -option messwert`

## Als Nächstes

- [ ] Widget „Historie Garten“ (klein, mittel, Sperrbildschirm; `/api/v1/historie?zeitraum=monate`, alle 30 Minuten)
      auf dem Gerät prüfen
- [ ] Historie: sobald der Pi `/api/v1/historie` hat, die echte Antwort mit den Beispieldaten vergleichen;
      Historie-Widget ist da (siehe oben)
- [ ] Andere Orte auf dem Gerät prüfen, sobald der Pi `/api/v1/ort` hat (Tageskontingent 25 Orte; 503-Text erscheint in der Liste)
- [ ] Widget mit Ort nach Wahl (eigener App-Intent-Parameter, da ohne App Group keine Favoriten im Widget)
- [ ] Umwelt & Himmel auf dem Gerät prüfen, sobald der Pi `/api/v1/umwelt` hat (bis dahin bleibt die Startseiten-Karte
      weg und die Seite sagt, dass der Server zu alt ist); mitgeliefertes Lexikon um die neuen Einträge ergänzen
- [ ] Widgets auf einem echten Gerät prüfen (Platzbedarf, Aktualisierung, Tippziele, Neuladen-Knopf)
- [ ] Widget „Messwert“ auf dem Gerät prüfen (Einstellung „Widget bearbeiten“, Aktualisierung)
- [ ] Siri auf dem Gerät prüfen (Siri-Sprache Deutsch; „Spexard“ muss Siri verstehen, sonst eigenen Kurzbefehl anlegen)
- [ ] Offline-Verhalten auf dem Gerät prüfen (Server nicht erreichbar)

## Hinweise

- Kein Mac: jeder Push auf `main` baut in GitHub Actions, macht Screenshots (`-mock`) und
  veröffentlicht die unsignierte IPA als Release `latest`.
- Keine Adressen und keine genauen Koordinaten ins Repository (öffentlich).
