# wa:sh – Entwicklung

Alles zum Bauen, Testen und Veröffentlichen. Was die App kann, steht im [README](../README.md).

## Bauen

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

### Benachrichtigungen (technisch)

Android sortiert die Benachrichtigungen nach Maschine, jede Kategorie lässt sich
einzeln abschalten oder anpassen (Ton, Vibration, „Bitte nicht stören“):

| Waschmaschine / Trockner | Wann | Standard |
|---|---|---|
| Läuft gerade | dauerhaft, mit Restzeit und Fortschritt | still |
| Gleich fertig | 10 Min. vor Ende | normal |
| Fertig | bei Ende | wichtig |
| Nachhaken | „nochmal erinnern“, „noch nicht abgeholt?“ | normal |

Direkt hin geht es über *Menü → Meine Programme → Benachrichtigungen*.

Auf iOS stapeln sich die Mitteilungen pro Maschine. Damit „Fertig“ auch durch
einen Fokus kommt: in Xcode beim Target *Runner* unter *Signing & Capabilities*
**Time Sensitive Notifications** hinzufügen.

### Android-Hinweis

Ist `JAVA_TOOL_OPTIONS` gesetzt (z. B. für Skalierung), stolpert Gradles JDK-Erkennung
darüber. Abhilfe: `env -u JAVA_TOOL_OPTIONS flutter run` bzw. als Alias.

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
git tag v0.4.0 && git push --tags
```

Die CI baut die APK und hängt sie an ein GitHub-Release.

Store-Texte für F-Droid / Play liegen unter `fastlane/metadata/android/de-DE/`,
die Datenschutzhinweise in [`PRIVACY.md`](../PRIVACY.md), alle Änderungen in
[`CHANGELOG.md`](../CHANGELOG.md).

Die Bilder im README entstehen aus den Doodles der App: `python3 tool/doodles_to_svg.py`.

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
docs/                        diese Doku, README-Bilder (docs/img, aus tool/doodles_to_svg.py)
```

Bei aktivierter Systemeinstellung „Bewegung reduzieren“ bleiben alle Animationen stehen.
Die Schriftgröße folgt der Systemeinstellung bis 130 %; alle Bedienelemente haben
Beschriftungen für Screenreader und sind mindestens 44 px groß.
