import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Plant die Erinnerungen für Waschmaschine und Trockner – unabhängig
/// voneinander, damit beide gleichzeitig laufen können.
///
/// IDs pro Maschine: base + 0 = „gleich fertig“, base + 1 = „fertig“,
/// base + 2 = „nochmal erinnern“, base + 4 = „noch nicht abgeholt?“.
/// (base + 3 gehört der nativen „läuft“-Anzeige aus dem Plugin wash_live.)
class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Wird aufgerufen, wenn jemand auf eine Benachrichtigung oder einen ihrer
  /// Buttons tippt. [action] ist `null` (Tipp auf die Nachricht selbst),
  /// [actionFinish] oder [actionOverview].
  void Function(Machine machine, String? action)? onOpen;

  static const actionFinish = 'finish';
  static const actionOverview = 'overview';

  static const _channel = AndroidNotificationDetails(
    'wash_reminders',
    'Wäsche-Erinnerungen',
    channelDescription: 'Sagt dir Bescheid, bevor und wenn deine Wäsche fertig ist.',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(
    android: _channel,
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_wash'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (r) => _handle(r.payload, r.actionId),
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingLaunchPayload = launch!.notificationResponse?.payload;
      _pendingLaunchAction = launch.notificationResponse?.actionId;
    }
    _ready = true;
  }

  String? _pendingLaunchPayload;
  String? _pendingLaunchAction;

  /// Falls die App über eine Benachrichtigung gestartet wurde: jetzt öffnen.
  void consumeLaunch() {
    final p = _pendingLaunchPayload;
    final a = _pendingLaunchAction;
    _pendingLaunchPayload = null;
    _pendingLaunchAction = null;
    _handle(p, a);
  }

  void _handle(String? payload, String? action) {
    if (payload == null) return;
    Machine m;
    try {
      m = Machine.values.byName(payload);
    } catch (_) {
      return;
    }
    onOpen?.call(m, (action == null || action.isEmpty) ? null : action);
  }

  /// Fragt beim ersten Start einer Ladung nach den nötigen Rechten.
  Future<void> requestPermissions() async {
    if (!_ready) return;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleRun(Run run) async {
    if (!_ready) return;
    await cancel(run.machine);
    final now = DateTime.now();
    final soon = run.end.subtract(reminderLead);
    if (soon.isAfter(now)) {
      await _at(
        run.machine.notificationBase,
        soon,
        'Gleich fertig',
        '${run.machine.label}: noch ${reminderLead.inMinutes} Minuten – mach dich langsam auf in den Keller.',
        run.machine,
      );
    }
    if (run.end.isAfter(now)) {
      await _at(
        run.machine.notificationBase + 1,
        run.end,
        run.machine == Machine.wash ? 'Wäsche ist fertig' : 'Trockner ist fertig',
        'Ab in den Keller – bevor sich der Nachbar deine Lieblingssocken ausleiht.',
        run.machine,
      );
    }
    // Nachhaken, falls 15 Minuten nach „fertig“ noch nichts abgeholt wurde.
    final nudge = run.end.add(const Duration(minutes: 15));
    if (nudge.isAfter(now)) {
      await _at(
        run.machine.notificationBase + 4,
        nudge,
        'Noch nicht abgeholt?',
        '${run.machine.label}: ${_nudges[run.end.minute % _nudges.length]}',
        run.machine,
      );
    }
  }

  /// Sprüche für „noch nicht abgeholt“ – wechseln, damit es nicht nervt.
  static const _nudges = [
    'Deine Socken fühlen sich langsam einsam.',
    'Der Keller hat angerufen: Deine Wäsche wartet.',
    'Die Nachbarn schielen schon auf die Maschine.',
    'Frisch gewaschen bleibt nur frisch, wenn sie rauskommt.',
    'Kurzer Ausflug in den Keller? Deine Wäsche freut sich.',
  ];

  Future<void> snooze(Machine machine, Duration delay) async {
    if (!_ready) return;
    await _at(
      machine.notificationBase + 2,
      DateTime.now().add(delay),
      'Noch da unten?',
      '${machine.label}: Deine Wäsche wartet noch auf dich.',
      machine,
    );
  }

  Future<void> cancel(Machine machine) async {
    if (!_ready) return;
    for (final i in const [0, 1, 2, 4]) {
      await _plugin.cancel(id: machine.notificationBase + i);
    }
  }

  Future<void> _at(int id, DateTime when, String title, String body, Machine machine) async {
    // Einmalige Erinnerungen brauchen nur den absoluten Zeitpunkt – in UTC
    // geplant, ist die Zeitzone des Geräts egal.
    final t = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: t,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: machine.name,
      );
    } catch (e) {
      // Ohne Recht auf exakte Wecker: ungenau, aber trotzdem erinnern.
      debugPrint('Exakter Wecker nicht erlaubt, plane ungenau: $e');
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: t,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: machine.name,
      );
    }
  }
}
