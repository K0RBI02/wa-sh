# wa:sh

[![CI](https://github.com/K0RBI02/wa-sh/actions/workflows/ci.yml/badge.svg)](https://github.com/K0RBI02/wa-sh/actions/workflows/ci.yml)

Nie wieder Wäsche im Keller vergessen. In Wohnanlagen stehen Waschmaschine und
Trockner meist im Keller – wa:sh stellt den Timer, erinnert dich rechtzeitig
und sagt Bescheid, wenn du runter musst. Waschmaschine und Trockner laufen
unabhängig voneinander, auch gleichzeitig.

Flutter-App für Android und iOS.

## Ablauf

1. **Starten** – Maschine wählen, eins der zwei gespeicherten Programme oder eine eigene Zeit
2. **Ruhig bleiben** – Countdown mit Ladebalken; Erinnerung 10 Minuten vor Ende
3. **Ab in den Keller** – Benachrichtigung wenn fertig, „in 5 Min nochmal erinnern“,
   nach dem Waschen direkt weiter in den Trockner

Die zwei Lieblingsprogramme pro Maschine lassen sich über das Menü oben rechts
auf dem Startscreen anpassen.

Außerdem:

- **„Läuft“-Anzeige**, solange eine Maschine läuft – Restzeit, Fortschrittsbalken,
  Buttons „Schon fertig“ und „Zur Übersicht“.
  - Android: dauerhafte Benachrichtigung über einen kleinen Vordergrund-Dienst;
    auf Android 16 als *Live Update* mit Chip in der Statusleiste.
  - iOS: *Live Activity* auf dem Sperrbildschirm und in der Dynamic Island (ab iOS 16.2).
- **Schnellstart:** App-Icon lange drücken → z. B. „Bunt 40° waschen“ startet den Timer sofort.
- **Nachhaken:** 15 Minuten nach „fertig“ noch nicht abgeholt → nächste Erinnerung (mit wechselnden Sprüchen).
- Vibration bei Auswahl, Start und Abholen; eigenes App-Icon; Schrift fest eingebaut.

## Loslegen

Voraussetzung: [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable), für iOS zusätzlich Xcode.

```bash
git clone git@github.com:K0RBI02/wa-sh.git && cd wa-sh
python3 tool/setup.py   # erzeugt Plugin, android/ und ios/, trägt Berechtigungen ein, baut das Icon
flutter run
```

`android/`, `ios/` und `packages/wash_live/` sind bewusst nicht im Repo: Sie werden
von `tool/setup.py` aus den Quellen unter `tool/` erzeugt. Nach Änderungen dort
einfach das Skript erneut laufen lassen.

`tool/setup.py` erledigt alles, was sich automatisieren lässt:

- erzeugt das eigene Plugin `packages/wash_live` und spielt die nativen Quellen aus
  `tool/wash_live/` ein (Android: Java-Dienst, Manifest, Statusleisten-Symbol; iOS: Swift)
- `flutter create` für die App, danach **Android:** Berechtigungen, Receiver von
  `flutter_local_notifications`, Core Library Desugaring, App-Name;
  **iOS:** App-Name, `NSSupportsLiveActivities`, URL-Schema `wash://`
- legt die Dateien der Widget-Erweiterung nach `ios/WashLiveWidget/`
- erzeugt das App-Icon (`flutter_launcher_icons`)

### iOS: Live Activity einrichten (einmalig, auf dem Mac)

Eine Widget-Erweiterung lässt sich nur in Xcode als eigenes Ziel anlegen:

1. `open ios/Runner.xcworkspace`
2. *File → New → Target… → Widget Extension*, Name **WashLiveWidget**,
   Haken bei *Include Live Activity* weg (wir bringen eigene Dateien mit), *Activate* bestätigen.
3. Die von Xcode erzeugten Swift-Dateien im Ordner *WashLiveWidget* löschen und
   stattdessen `ios/WashLiveWidget/WashLiveWidget.swift` und
   `ios/WashLiveWidget/WashLiveAttributes.swift` zum Ziel **WashLiveWidget** hinzufügen.
4. Beim Ziel *WashLiveWidget* das Deployment-Target auf **iOS 16.2** setzen.
5. Bauen. Beim ersten Timer fragt iOS, ob Live Activities erlaubt sind.

Ohne diese Erweiterung läuft die App auf iOS trotzdem – nur ohne Live Activity.

Falls Benachrichtigungen bei geöffneter App auf iOS nicht erscheinen: in
`ios/Runner/AppDelegate.swift` beim Start ergänzen

```swift
UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
```

Hinweis zu neueren Flutter-Vorlagen mit `SceneDelegate`: Kommen die Buttons der Live
Activity („Schon fertig“, „Zur Übersicht“) in der App nicht an, muss der Szenen-Delegate
die `wash://`-Links weiterreichen – Tipp auf die Live Activity selbst öffnet die App in jedem Fall.

### Android-Hinweis

Ist `JAVA_TOOL_OPTIONS` gesetzt (z. B. für Skalierung), stolpert Gradles JDK-Erkennung
darüber. Abhilfe: `env -u JAVA_TOOL_OPTIONS flutter run` bzw. als Alias.

## Home Assistant

wa:sh bringt eine eigene Home-Assistant-Integration mit (`custom_components/wash`).
Die App meldet direkt an Home Assistant – ohne Zwischenserver, ohne Token.

### Installieren

**Über HACS:** HACS → ⋮ → *Benutzerdefinierte Repositories* →
`https://github.com/K0RBI02/wa-sh`, Typ *Integration* → **wa:sh** herunterladen →
Home Assistant neu starten.

**Von Hand:** Ordner `custom_components/wash` nach `/config/custom_components/wash`
kopieren, Home Assistant neu starten.

### Koppeln

1. Home Assistant → *Einstellungen → Geräte & Dienste → Integration hinzufügen* → **wa:sh** → Namen vergeben (z. B. „Waschküche“).
2. HA zeigt den **Kopplungscode** groß an (z. B. `K7Q-2M9`, 10 Min. gültig) und wartet.
   In der App: *Menü → Meine Programme → Home Assistant* → Adresse und Code eintragen → **Koppeln**.
3. Sobald das Handy gekoppelt ist, geht der Dialog in HA von selbst weiter – fertig.

Ein weiteres Handy koppelt man über **Konfigurieren** am Eintrag. Mit Nabu Casa
bekommt die App zusätzlich eine Cloud-Adresse und meldet auch, wenn sie das
Heimnetz nicht erreicht. Unter *⋮ → Diagnose herunterladen* gibt es den aktuellen
Stand (ohne Kopplungsdaten) für Fehlerberichte.

### Was in HA ankommt

Zwei Geräte – **Waschmaschine** und **Trockner** – mit je:

| Entität | Inhalt |
|---|---|
| Status | Frei · Läuft · Fertig |
| Läuft | Binärsensor, an solange die Maschine läuft |
| Fertig um | Zeitstempel |
| Restzeit | Minuten |
| Fortschritt | % |
| Programm | z. B. „Bunt 40°“ |

Die Integration rechnet das Ende selbst aus: Sie schaltet pünktlich auf „Fertig“,
auch wenn das Handy aus ist, und behält den Stand über HA-Neustarts.

Für Automationen gibt es außerdem die Ereignisse `wash_started`, `wash_finished`
und `wash_collected` (Daten: `machine`, `name`, `program`, `end`).

Beispiel – Durchsage und Licht, wenn die Wäsche fertig ist:

```yaml
automation:
  - alias: "Wäsche fertig – Durchsage"
    triggers:
      - trigger: event
        event_type: wash_finished
    actions:
      - action: tts.speak
        target:
          entity_id: tts.google_translate_de_de
        data:
          media_player_entity_id: media_player.wohnzimmer
          message: "{{ trigger.event.data.name }} ist fertig – ab in den Keller."
      - action: light.turn_on
        target:
          entity_id: light.flur
        data:
          flash: short
```

## Entwicklung

```bash
flutter analyze
flutter test        # Kernlogik: Laufzeiten, parallele Maschinen, Speichern, HA-Kopplung

pip install pytest-homeassistant-custom-component
python -m pytest    # HA-Integration gegen ein echtes Home Assistant
```

Jeder Push auf `main` läuft durch die CI (GitHub Actions): Setup, Analyse, Tests und
eine Release-APK als Download unter *Actions → Artefakte*.

## Release

**Signatur einrichten (einmalig):**

```bash
keytool -genkey -v -keystore ~/wa-sh-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias wash
```

Lokal: `android/key.properties` anlegen (wird nicht eingecheckt) –

```properties
storePassword=…
keyPassword=…
keyAlias=wash
storeFile=/home/korbi/wa-sh-upload.jks
```

– dann `flutter build apk --release`.

Für die CI unter *Settings → Secrets and variables → Actions* hinterlegen:
`KEYSTORE_BASE64` (`base64 -w0 ~/wa-sh-upload.jks`), `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
`KEY_PASSWORD`. Ohne Secrets signiert die CI mit dem Debug-Schlüssel.

**Version veröffentlichen:** `version:` in `pubspec.yaml` erhöhen, `CHANGELOG.md`
ergänzen, dann

```bash
git tag v0.2.0 && git push --tags
```

Die CI baut die APK und hängt sie an ein GitHub-Release.

Store-Texte für F-Droid / Play liegen unter `fastlane/metadata/android/de-DE/`,
die Datenschutzhinweise in [`PRIVACY.md`](PRIVACY.md), alle Änderungen in
[`CHANGELOG.md`](CHANGELOG.md).

## Aufbau

```
lib/
  main.dart                 Start, Navigation bei Tipp auf Erinnerungen, Schnellstart
  models.dart               Maschine, Programm, Durchgang
  store.dart                Zustand + Speicherung (shared_preferences)
  ha.dart                   Kopplung + Meldungen an die HA-Integration
  notifications.dart        geplante Erinnerungen pro Maschine
  theme.dart                Farben, Schrift (Instrument Sans, assets/fonts, OFL)
  widgets/doodle.dart       Doodle-Renderer mit dezenten Animationen
  widgets/doodles.dart      die Illustrationen
  widgets/common.dart       Schrittanzeige, Buttons
  screens/home_screen.dart  Start mit einer Kachel pro Maschine
  screens/start_screen.dart Schritt 1
  screens/machine_flow.dart Schritt 2 und 3
  screens/programs_sheet.dart „Meine Programme“
packages/wash_live/          (erzeugt) natives Plugin für die „läuft“-Anzeige
tool/wash_live/              Quellen dafür: android/ (Java), ios/ (Swift), lib/
tool/ios_widget/             iOS-Widget-Erweiterung (Live Activity, Dynamic Island)
custom_components/wash/      Home-Assistant-Integration (HACS)
tests/                       Tests der Integration (pytest)
```

Bei aktivierter Systemeinstellung „Bewegung reduzieren“ bleiben alle Animationen stehen.
Die Schriftgröße folgt der Systemeinstellung bis 130 %; alle Bedienelemente haben
Beschriftungen für Screenreader und sind mindestens 44 px groß.
