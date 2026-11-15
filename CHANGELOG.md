# Changelog

## 0.4.0 – unveröffentlicht

### App
- Neues App-Icon: der Wäschekorb (auch als angepasstes Android-Icon und
  einfarbiges „Themed Icon“).
- Benachrichtigungen nach Maschine gruppiert, jede Kategorie einzeln
  einstellbar: Läuft gerade · Gleich fertig · Fertig · Nachhaken.
- „Benachrichtigungen“ in „Meine Programme“ öffnet direkt die
  System-Einstellungen der App.
- iOS: Mitteilungen pro Maschine gestapelt; „Fertig“ als zeitkritisch
  (dringt durch einen Fokus, wenn die Fähigkeit aktiviert ist).
- Android: Sicherung schließt die verschlüsselten HA-Kopplungsdaten aus
  (verhindert Fehler nach dem Wiederherstellen auf einem neuen Handy);
  Zurück-Geste mit Vorschau.

### Home Assistant
- Wäschekorb als Icon; „Läuft“ mit Waschmaschinen- bzw. Trockner-Symbol.

## 0.3.1

### Home Assistant
- Einrichtung in drei Schritten: Name → Kopplungscode auf eigenem Screen →
  „Gekoppelt“. Der Dialog wartet aufs Handy und geht von selbst weiter.
- Abgelaufener Code: neuer Code mit einem Klick; geschlossener Dialog macht
  den Code sofort ungültig.
- Eigenes Icon in HA und HACS.
- Diagnose-Download (ohne Kopplungsdaten).
- War eine Maschine fertig, während HA aus war, wird „fertig“ nach dem Start
  nachgeholt.

### App
- Layoutfehler bei „Verbindung testen / Trennen“ behoben.

## 0.3.0

### Neu
- Eigene Home-Assistant-Integration „wa:sh“ (HACS): Geräte Waschmaschine und
  Trockner mit Status, „Läuft“, Fertig um, Restzeit, Fortschritt, Programm;
  Ereignisse `wash_started` / `wash_finished` / `wash_collected`.
- Kopplung über einen Code aus Home Assistant statt Long-Lived-Token.
- HA schaltet selbst pünktlich auf „Fertig“ und behält den Stand über Neustarts.
- Mit Nabu Casa: Ausweich-Adresse über die Cloud.
- Home-Assistant-Bereich in den Einstellungen einklappbar.

### Geändert
- Die alte REST-Anbindung (`sensor.wash_*` per Token) entfällt; ein gespeicherter
  Token wird beim Update gelöscht. Einmal neu koppeln.

## 0.2.0 – 2026-11-15

### Neu
- „Läuft“-Anzeige pro Maschine mit Restzeit, Fortschrittsbalken und den Buttons „Schon fertig“ / „Zur Übersicht“
  - Android: eigener Vordergrund-Dienst, läuft auch bei geschlossener App weiter; ab Android 16 QPR1 als Live Update mit Chip in der Statusleiste
  - iOS: Live Activity auf dem Sperrbildschirm und in der Dynamic Island
- Schnellstart über das App-Icon (lange drücken) – startet ein gespeichertes Programm sofort
- „Noch nicht abgeholt?“ – Erinnerung 15 Minuten nach „fertig“ mit wechselnden Sprüchen
- Home-Assistant-Anbindung: Status, Programm und „fertig um“ als Sensoren
- Vibration bei Auswahl, Start und Abholen
- Eigenes App-Icon und Statusleisten-Symbol, Schrift fest eingebaut

### Geändert
- Schritt 2: „Zur Übersicht“ und „Schon fertig“ statt „Timer stoppen“
- Schritt-Anzeige einheitlich 4 px
- HA-Token wird verschlüsselt gespeichert (Android Keystore / iOS Keychain)
- Schriftgröße folgt der Systemeinstellung (bis 130 %)
- flutter_local_notifications 22, timezone 0.11

## 0.1.0 – 2026-11-14

- Erste Version: Start mit Kachel pro Maschine, 3-Schritte-Ablauf (Starten → Läuft → Abholen),
  Waschmaschine und Trockner parallel, zwei gespeicherte Programme pro Maschine plus eigene Zeit,
  Erinnerung 10 Minuten vor Ende und bei „fertig“, animierte Doodles
