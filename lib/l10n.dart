import 'dart:ui' show Locale, PlatformDispatcher;

import 'models.dart';

/// Texte der App auf Deutsch und Englisch.
///
/// Bewusst ohne Code-Generator: Die Texte werden auch außerhalb von Widgets
/// gebraucht (Benachrichtigungen, Schnellstart, „läuft“-Anzeige), deshalb gibt
/// es eine globale Sprache [t], die beim Start und bei Sprachwechsel des
/// Systems gesetzt wird. Deutsch für `de`, sonst Englisch.
class S {
  const S._(this.de);

  final bool de;

  static const german = S._(true);
  static const english = S._(false);

  static const supportedLocales = [Locale('de'), Locale('en')];

  static S forLocale(Locale? l) => l?.languageCode == 'de' ? german : english;

  /// Sprache des Systems bzw. die für die App gewählte Sprache (Android 13+, iOS).
  static S fromSystem() => forLocale(PlatformDispatcher.instance.locale);

  String get code => de ? 'de' : 'en';

  String _(String d, String e) => de ? d : e;

  // ── Maschinen ─────────────────────────────────────────────
  String machine(Machine m) => m == Machine.wash ? _('Waschmaschine', 'Washer') : _('Trockner', 'Dryer');
  String machineShort(Machine m) => m == Machine.wash ? _('Wäsche', 'Washer') : _('Trockner', 'Dryer');
  String verb(Machine m) => m == Machine.wash ? _('Waschen', 'Wash') : _('Trocknen', 'Dry');
  String machineRunningTitle(Machine m) => m == Machine.wash ? _('Wäsche läuft', 'Washer running') : _('Trockner läuft', 'Dryer running');

  // ── Zeit ──────────────────────────────────────────────────
  String get hoursUnit => _('Std', 'h');
  String get minutesUnit => 'Min';
  String finishesAt(String clock) => _('fertig um $clock', 'done at $clock');
  String finishesAtCap(String clock) => _('Fertig um $clock', 'Done at $clock');

  // ── Startscreen ───────────────────────────────────────────
  String get homeDoneTitle => _('Fertig!\nAbholen.', 'Done!\nCollect.');
  String get homeDoneBody => _('Mindestens eine Maschine ist durch – ab in den Keller.', 'At least one machine is done – down to the basement.');
  String get homeBothTitle => _('Alles\nläuft.', 'All\nrunning.');
  String get homeBothBody => _('Waschmaschine und Trockner drehen gleichzeitig – wir behalten beide im Blick.',
      'Washer and dryer are both spinning – we keep an eye on both.');
  String get homeOneTitle => _('Eins\nläuft.', 'One\nrunning.');
  String homeOneBody(bool washRunning) => washRunning
      ? _('Der Trockner ist noch frei – soll er gleich mit?', 'The dryer is still free – start it too?')
      : _('Die Waschmaschine ist noch frei.', 'The washer is still free.');
  String get homeIdleTitle => _('Heute\nWaschtag?', 'Laundry\nday?');
  String get homeIdleBody => _('Gerade läuft nichts. Starte eine Ladung – wir erinnern dich, bevor sie fertig ist.',
      "Nothing's running. Start a load – we'll remind you before it's done.");
  String get tagSocks => _('Keine Socke bleibt zurück.', 'No sock left behind.');
  String get tagTwo => _('Zwei Maschinen, null Stress.', 'Two machines, zero stress.');
  String get myPrograms => _('Meine Programme', 'My programs');
  String startMachine(Machine m) => _('${machine(m)} starten', 'Start ${machine(m).toLowerCase()}');
  String machineDoneCollect(Machine m) => _('${machine(m)} fertig – abholen', '${machine(m)} done – collect');
  String machineRunningFor(Machine m, int minutes) =>
      _('${machine(m)} läuft, noch $minutes Minuten', '${machine(m)} running, $minutes minutes left');
  String get idle => _('frei', 'free');
  String get start => _('Starten', 'Start');
  String get done => _('Fertig', 'Done');
  String get collectExcl => _('abholen!', 'collect!');
  String runningChip(Machine m) => _('${machineShort(m)} läuft', '${machineShort(m)} running');
  String get since => _('seit ', 'since ');
  String get doneAtLabel => _('fertig ', 'done ');

  // ── Schritt 1 ─────────────────────────────────────────────
  String alreadyRunning(Machine m) => _('${machine(m)} läuft schon', '${machine(m)} is already running');
  String get replaceTimer => _('Der laufende Timer wird ersetzt.', 'The running timer will be replaced.');
  String get keep => _('Behalten', 'Keep');
  String get restart => _('Neu starten', 'Restart');
  String get customTime => _('Eigene Zeit', 'Custom time');
  String get startTitle => _('Wäsche\nStarten', 'Start\nLaundry');
  String get startBody => _('Wähle **dein Programm** oder stell eine eigene Zeit ein – wir behalten sie für dich im Blick.',
      "Pick **your program** or set a custom time – we'll keep an eye on it for you.");
  String get startTimer => _('Timer starten', 'Start timer');
  String get changedMind => _('Doch nicht?', 'Changed your mind?');
  String get back => _('Zurück', 'Back');
  String get custom => _('Eigene', 'Custom');
  String get pickTime => _('Zeit wählen', 'Pick time');
  String get minus15 => _('15 Minuten weniger', '15 minutes less');
  String get plus15 => _('15 Minuten mehr', '15 minutes more');
  String get applyTime => _('Zeit übernehmen', 'Use this time');

  // ── Schritt 2 ─────────────────────────────────────────────
  String get relaxTitle => _('Ruhig\nBleiben', 'Stay\nCalm');
  String runningBody(Machine m, int lead) =>
      '${m == Machine.wash ? _('Deine Wäsche dreht ihre Runden', 'Your laundry is doing its laps') : _('Der Trockner pustet fleißig', 'The dryer is busy blowing')}. '
      '${_('Wir **erinnern dich $lead Minuten vorher** – du musst nicht in den Keller schauen.', "We'll **remind you $lead minutes before** – no need to check the basement.")}';
  String get toOverview => _('Zur Übersicht', 'Overview');
  String get alreadyDone => _('Schon fertig', 'Already done');
  String get justNow => _('gerade eben', 'just now');
  String sinceMinutes(int m) => _('seit $m Min', 'for $m min');
  String sinceHours(int h, int m) => _('seit $h Std $m Min', 'for ${h}h $m min');

  // ── Schritt 3 ─────────────────────────────────────────────
  String get basementTitle => _('Ab in den\nKeller', 'Down to the\nBasement');
  String doneBody(Machine m) => m == Machine.wash
      ? _('Deine Wäsche ist **fertig**. Hol sie raus, bevor sich der Nachbar deine Lieblingssocken ausleiht.',
          'Your laundry is **done**. Get it out before the neighbour borrows your favourite socks.')
      : _('Der Trockner ist **fertig**. Hol sie raus, bevor sich der Nachbar deine Lieblingssocken ausleiht.',
          'The dryer is **done**. Get it out before the neighbour borrows your favourite socks.');
  String get doneSpace => _('Fertig ', 'Done ');
  String get onToDryer => _('Weiter in den Trockner', 'On to the dryer');
  String get onToDryerSub => _('Trockner-Timer gleich mitstarten', 'Start the dryer timer right away');
  String get collected => _('Abgeholt', 'Collected');
  String get noTime => _('Gerade keine Zeit?', 'No time right now?');
  String get remind5 => _('In 5 Min erinnern', 'Remind me in 5 min');
  String get willRemind5 => _('Erinnere dich in 5 Min', "I'll remind you in 5 min");

  // ── Schrittanzeige ────────────────────────────────────────
  String step(int n) => _('Schritt $n von 3', 'Step $n of 3');
  String stepProgress(int n, int pct) => _('Schritt $n von 3, $pct Prozent geschafft', 'Step $n of 3, $pct percent done');

  // ── Meine Programme ───────────────────────────────────────
  String get twoFavourites => _('Zwei Favoriten pro Maschine', 'Two favourites per machine');
  String get close => _('Schließen', 'Close');
  String get programsHint => _('Die Programme erscheinen beim Starten direkt zur Auswahl. Für alles andere gibt’s „Eigene Zeit“.',
      'Your programs show up right away when starting. For everything else there’s “Custom time”.');
  String get save => _('Speichern', 'Save');
  String program(int n) => _('Programm $n', 'Program $n');
  String programMinus(int n) => _('Programm $n: 5 Minuten weniger', 'Program $n: 5 minutes less');
  String programPlus(int n) => _('Programm $n: 5 Minuten mehr', 'Program $n: 5 minutes more');
  String get notifications => _('Benachrichtigungen', 'Notifications');
  String get notificationsSub => _('Pro Maschine einzeln einstellen', 'Adjust per machine');
  String get notificationsOpen => _('Benachrichtigungen in den Systemeinstellungen öffnen', 'Open notifications in system settings');

  // ── Home Assistant ────────────────────────────────────────
  String get haPaired => _('Gekoppelt', 'Paired');
  String get haReachable => _('Erreichbar', 'Reachable');
  String get haAddress => _('Adresse', 'Address');
  String get haCode => _('Kopplungscode', 'Pairing code');
  String get haCodeHint => _('z. B. K7Q-2M9', 'e.g. K7Q-2M9');
  String get haPair => _('Koppeln', 'Pair');
  String get haTest => _('Verbindung testen', 'Test connection');
  String get haUnpair => _('Trennen', 'Unpair');
  String haPairedWith(String name) => _('Gekoppelt mit „$name“', 'Paired with “$name”');
  String get haIntro => _('Optional: In Home Assistant „Integration hinzufügen → wa:sh“ wählen, dann hier den Code eingeben.',
      'Optional: In Home Assistant choose “Add integration → wa:sh”, then enter the code here.');
  String get haErrNoAddress => _('Adresse eintragen', 'Enter the address');
  String get haErrNoCode => _('Code aus Home Assistant eintragen', 'Enter the code from Home Assistant');
  String get haErrBadCode => _('Code ungültig oder abgelaufen', 'Code invalid or expired');
  String get haErrNoIntegration => _('wa:sh-Integration in HA nicht gefunden', 'wa:sh integration not found in HA');
  String get haErrTooMany => _('Zu viele Versuche – kurz warten', 'Too many attempts – wait a moment');
  String haErrStatus(int s) => _('HA antwortet mit Status $s', 'HA responded with status $s');
  String get haErrUnexpected => _('Unerwartete Antwort von HA', 'Unexpected response from HA');
  String get haErrNotPaired => _('Noch nicht gekoppelt', 'Not paired yet');
  String get haErrRemoved => _('Kopplung in HA gelöscht – neu koppeln', 'Pairing removed in HA – pair again');
  String get haErrUnreachable => _('HA nicht erreichbar', 'HA not reachable');
  String get haErrCert => _('Zertifikat-Problem (https)', 'Certificate problem (https)');
  String get haErrBadAddress => _('Adresse ungültig', 'Invalid address');
  String haErrOther(Object e) => _('Fehler: $e', 'Error: $e');

  // ── Benachrichtigungen ────────────────────────────────────
  String get chRunning => _('Läuft gerade', 'Running');
  String get chRunningDesc => _('Dauerhafte Anzeige mit Restzeit und Fortschritt.', 'Persistent display with time left and progress.');
  String get chSoon => _('Gleich fertig', 'Almost done');
  String get chSoonDesc => _('10 Minuten vor Ende – Zeit, sich auf den Weg zu machen.', '10 minutes before the end – time to head down.');
  String get chDone => _('Fertig', 'Done');
  String get chDoneDesc => _('Wenn die Maschine fertig ist.', 'When the machine is done.');
  String get chNudge => _('Nachhaken', 'Nudges');
  String get chNudgeDesc => _('„Nochmal erinnern“ und „Noch nicht abgeholt?“.', '“Remind me again” and “Not collected yet?”.');
  String groupDesc(Machine m) => m == Machine.wash
      ? _('Alles rund um die Waschmaschine.', 'Everything about the washer.')
      : _('Alles rund um den Trockner.', 'Everything about the dryer.');

  String get soonTitle => _('Gleich fertig', 'Almost done');
  String soonBody(Machine m, int lead) =>
      _('${machine(m)}: noch $lead Minuten – mach dich langsam auf in den Keller.', '${machine(m)}: $lead minutes left – time to head to the basement.');
  String doneTitle(Machine m) =>
      m == Machine.wash ? _('Wäsche ist fertig', 'Laundry is done') : _('Trockner ist fertig', 'Dryer is done');
  String get doneNotifBody =>
      _('Ab in den Keller – bevor sich der Nachbar deine Lieblingssocken ausleiht.', 'Down to the basement – before the neighbour borrows your favourite socks.');
  String get nudgeTitle => _('Noch nicht abgeholt?', 'Not collected yet?');
  List<String> get nudges => de
      ? const [
          'Deine Socken fühlen sich langsam einsam.',
          'Der Keller hat angerufen: Deine Wäsche wartet.',
          'Die Nachbarn schielen schon auf die Maschine.',
          'Frisch gewaschen bleibt nur frisch, wenn sie rauskommt.',
          'Kurzer Ausflug in den Keller? Deine Wäsche freut sich.',
        ]
      : const [
          'Your socks are starting to feel lonely.',
          'The basement called: your laundry is waiting.',
          'The neighbours are eyeing the machine already.',
          'Fresh laundry only stays fresh if it comes out.',
          'Quick trip to the basement? Your laundry will be glad.',
        ];
  String get snoozeTitle => _('Noch da unten?', 'Still down there?');
  String snoozeBody(Machine m) => _('${machine(m)}: Deine Wäsche wartet noch auf dich.', '${machine(m)}: your laundry is still waiting for you.');

  // ── Schnellstart ──────────────────────────────────────────
  String shortcut(Machine m, String program) =>
      m == Machine.wash ? _('$program waschen', 'Wash $program') : _('$program trocknen', 'Dry $program');
  String startedSnack(String program, String clock) => _('$program läuft – fertig um $clock', '$program running – done at $clock');

  // ── Standardprogramme (nur für neue Installationen) ──────
  List<Program> defaultPrograms(Machine m) => switch ((m, de)) {
        (Machine.wash, true) => const [Program('Bunt 40°', 105), Program('Handtücher 60°', 130)],
        (Machine.wash, false) => const [Program('Colours 40°', 105), Program('Towels 60°', 130)],
        (Machine.dry, true) => const [Program('Baumwolle', 100), Program('Pflegeleicht', 60)],
        (Machine.dry, false) => const [Program('Cotton', 100), Program('Easy care', 60)],
      };
}

/// Aktuelle Sprache der App. Standard Deutsch (u. a. für Tests), beim Start
/// und bei Sprachwechsel aus dem System gesetzt.
S t = S.german;
