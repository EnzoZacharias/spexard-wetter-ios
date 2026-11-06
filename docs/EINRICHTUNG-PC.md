# Einrichtung des Windows-PCs (AltServer) – Anleitung für Claude Code

Ich möchte meine eigene iPhone-App "Spexard Wetter" per AltStore auf mein iPhone 17 Pro bringen,
ohne Apple-Entwicklerkonto (kostenlose Apple-ID). Dieser Windows-PC soll dauerhaft der AltServer
sein, der die App-Signatur wöchentlich per WLAN verlängert. Bitte führ mich Schritt für Schritt
durch die Einrichtung und erledige alles, was per Kommandozeile geht, selbst.

## Kontext

- App-Repo (öffentlich): https://github.com/EnzoZacharias/spexard-wetter-ios
- Fertige, unsignierte App-Datei (AltStore signiert sie):
  https://github.com/EnzoZacharias/spexard-wetter-ios/releases/latest/download/SpexardWetter.ipa
- Die App holt ihre Daten von meinem Wetterserver im Heimnetz (Home-Assistant-App auf dem
  Raspberry Pi). Die Adresse steht in der App unter Einstellungen. Prüf einmal, dass der Server
  von diesem PC aus antwortet: `<server>/healthz` muss `{"status":"ok", ...}` liefern.

## Regeln

- Meine Apple-ID und mein Passwort gebe ich nur selbst in AltServer bzw. am iPhone ein. Frag nie
  danach und speichere sie nirgends.
- Die Voraussetzungen von AltStore ändern sich gelegentlich. Lies deshalb zuerst die aktuelle
  offizielle Anleitung für Windows auf https://altstore.io bzw. https://faq.altstore.io und halte
  dich daran, nicht an Wissen aus dem Gedächtnis. Das gilt besonders für die Frage, welche iTunes-
  und iCloud-Versionen nötig sind: früher mussten es die Versionen direkt von apple.com sein, nicht
  die aus dem Microsoft Store.
- Prüf vorher, was schon installiert ist (Windows-Version, iTunes, iCloud, AltServer), und
  installiere nur, was fehlt. Wo winget die richtige Version liefert, nimm winget.

## Schritte

1. Voraussetzungen laut aktueller AltStore-Anleitung installieren (iTunes, iCloud, AltServer).
2. AltServer starten und so einrichten, dass er mit Windows automatisch startet (Infobereich).
3. Mich anleiten: iPhone per USB anschließen, "Diesem Computer vertrauen", in iTunes beim iPhone
   "Mit diesem iPhone über WLAN synchronisieren" aktivieren.
4. Über das AltServer-Symbol im Infobereich: "Install AltStore" -> mein iPhone. Die Apple-ID gebe
   ich selbst ein.
5. Am iPhone: Einstellungen -> Allgemein -> VPN & Geräteverwaltung -> meiner Apple-ID vertrauen;
   Einstellungen -> Datenschutz & Sicherheit -> Entwicklermodus einschalten (iPhone startet neu).
6. Spexard Wetter installieren, eine der beiden Varianten:
   a) am iPhone in Safari die .ipa-URL oben öffnen -> Teilen -> AltStore, oder
   b) die .ipa auf diesen PC laden und per AltServer "Sideload .ipa" aufs iPhone spielen.
7. App öffnen und prüfen, dass im Heim-WLAN die Wetterdaten kommen (Zahnrad -> "Verbindung testen").
8. Zum Schluss: Fasse mir kurz zusammen, was eingerichtet ist und was ich wöchentlich tun muss:
   PC mit AltServer und iPhone im selben WLAN, AltStore verlängert dann automatisch; sonst in
   AltStore unter "My Apps" auf "Refresh All". Erklär auch, wie ich später eine neue Version der
   App installiere (dieselbe .ipa-URL, sie wird bei jedem Build ersetzt).

Wenn etwas hakt (z. B. AltServer findet das iPhone nicht), such die Ursache in der offiziellen
AltStore-FAQ, bevor du Workarounds probierst.
