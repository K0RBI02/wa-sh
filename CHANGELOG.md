# Changelog

## 0.5.1 – unreleased

### App
- Dark mode reworked: the pastel cards and step screens stay light with dark
  text (“light islands”), only the neutral surfaces go dark.

## 0.5.0 – 2026-11-15

### App
- Dark mode: follows the system, doodles invert (light lines on dark surfaces).
- Status bar icon is now the laundry basket.
- Start a timer from a link or an NFC sticker at the machine (`wash://start?…`);
  the new website creates such stickers.

### Home Assistant
- Start and collect from Home Assistant: program select, Start and Collected
  buttons per machine, actions `wash.start` / `wash.collect`.
- The app and Home Assistant sync both ways; the most recent change wins.

## 0.4.0 – 2026-11-15

### App
- **English and German**: the app follows the phone's language and switches
  live – texts, notifications, quick actions and the “running” display. Android 13+
  and iOS offer a per-app language setting. New installations start with
  programs in the matching language.
- New app icon: the laundry basket (also as Android adaptive icon and
  monochrome “themed icon”).
- Notifications grouped by machine, each category adjustable on its own:
  Running · Almost done · Done · Nudges.
- “Benachrichtigungen” in “Meine Programme” opens the app's system
  notification settings directly.
- iOS: notifications stacked per machine; “done” marked time-sensitive
  (breaks through a Focus once the capability is enabled).
- Android: backups exclude the encrypted Home Assistant pairing data
  (prevents errors after restoring onto a new phone); predictive back gesture.

### Home Assistant
- Laundry basket icon; “Running” shows a washer or dryer symbol.

### Repository
- README rewritten around the app, technical docs moved to `docs/`, all in English.

## 0.3.1

### Home Assistant
- Setup in three steps: name → pairing code on its own screen → “paired”.
  The dialog waits for the phone and continues on its own.
- Expired code: new code with one click; closing the dialog invalidates the
  code immediately.
- Own icon in Home Assistant and HACS.
- Diagnostics download (without pairing data).
- If a machine finished while Home Assistant was down, “done” is caught up
  after the restart.

### App
- Fixed layout overflow at “Verbindung testen / Trennen”.

## 0.3.0

### Added
- Own Home Assistant integration “wa:sh” (HACS): Washer and Dryer devices with
  status, running, finishes at, time left, progress and program; events
  `wash_started` / `wash_finished` / `wash_collected`.
- Pairing with a code shown by Home Assistant instead of a long-lived token.
- Home Assistant switches to “done” on time by itself and keeps its state across restarts.
- With Nabu Casa: fallback address via the cloud.
- Collapsible Home Assistant section in the settings.

### Changed
- The old REST connection (`sensor.wash_*` via token) is gone; a stored token is
  deleted on update. Pair once again.

## 0.2.0 – 2026-11-15

### Added
- “Running” display per machine with time left, progress bar and the buttons
  “Schon fertig” / “Zur Übersicht”
  - Android: own foreground service that keeps running with the app closed; from
    Android 16 QPR1 as a Live Update with a status bar chip
  - iOS: Live Activity on the lock screen and in the Dynamic Island
- Quick start from the app icon (long-press) – starts a saved program right away
- “Not collected yet?” – reminder 15 minutes after “done” with rotating one-liners
- Home Assistant connection: status, program and “finishes at” as sensors
- Haptics on selection, start and collection
- Own app icon and status bar icon, bundled font

### Changed
- Step 2: “Zur Übersicht” and “Schon fertig” instead of “stop timer”
- Step indicator consistently 4 px
- Home Assistant token stored encrypted (Android Keystore / iOS Keychain)
- Text size follows the system setting (up to 130 %)
- flutter_local_notifications 22, timezone 0.11

## 0.1.0 – 2026-11-14

- First version: home screen with a tile per machine, 3-step flow
  (start → running → collect), washer and dryer in parallel, two saved programs
  per machine plus custom time, reminder 10 minutes before the end and when done,
  animated doodles
