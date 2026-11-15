import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wash_live/wash_live.dart';

import 'ha.dart';
import 'models.dart';
import 'notifications.dart';
import 'l10n.dart';

/// Hält Programme und laufende Durchgänge. Waschmaschine und Trockner haben
/// je einen eigenen Slot und laufen völlig unabhängig voneinander.
class WashStore extends ChangeNotifier {
  WashStore._(this._prefs);

  static const _kPrograms = 'programs.v1';
  static const _kRuns = 'runs.v1';

  final SharedPreferences _prefs;
  final Map<Machine, List<Program>> _programs = {
    for (final m in Machine.values) m: List.of(defaultPrograms[m]!),
  };
  final Map<Machine, Run> _runs = {};
  Timer? _ticker;
  final Set<Machine> _doneReported = {};

  static Future<WashStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = WashStore._(prefs);
    s._read();
    s._ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (s._runs.isEmpty) return;
      s._reportFinished();
      s.notifyListeners();
    });
    // Home Assistant auf den aktuellen Stand bringen.
    for (final m in Machine.values) {
      final r = s._runs[m];
      if (r != null && r.isDone(DateTime.now())) s._doneReported.add(m);
      HomeAssistant.instance.report(m, r);
    }
    // Native „läuft“-Anzeige nach einem Neustart wieder herstellen.
    for (final r in s._runs.values) {
      if (!r.isDone(DateTime.now())) _showLive(r);
    }
    return s;
  }

  void _read() {
    try {
      final p = _prefs.getString(_kPrograms);
      if (p != null) {
        final j = jsonDecode(p) as Map<String, dynamic>;
        for (final m in Machine.values) {
          final list = (j[m.name] as List?)?.cast<Map<String, dynamic>>();
          if (list != null && list.length == 2) {
            _programs[m] = list.map(Program.fromJson).toList();
          }
        }
      }
      final r = _prefs.getString(_kRuns);
      if (r != null) {
        for (final e in (jsonDecode(r) as List).cast<Map<String, dynamic>>()) {
          final run = Run.fromJson(e);
          _runs[run.machine] = run;
        }
      }
    } catch (e) {
      debugPrint('Gespeicherte Daten unlesbar, starte frisch: $e');
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
      _kPrograms,
      jsonEncode({for (final m in Machine.values) m.name: _programs[m]!.map((p) => p.toJson()).toList()}),
    );
    await _prefs.setString(_kRuns, jsonEncode(_runs.values.map((r) => r.toJson()).toList()));
  }

  // ── Programme ────────────────────────────────────────────

  List<Program> programs(Machine m) => List.unmodifiable(_programs[m]!);

  void updateProgram(Machine m, int index, Program p) {
    _programs[m]![index] = p;
    notifyListeners();
    _save();
  }

  // ── Durchgänge ───────────────────────────────────────────

  Run? run(Machine m) => _runs[m];
  bool get anyRunning => _runs.isNotEmpty;

  Future<Run> start(Machine m, String programName, int minutes) async {
    final now = DateTime.now();
    final run = Run(machine: m, programName: programName, start: now, end: now.add(Duration(minutes: minutes)));
    _runs[m] = run;
    notifyListeners();
    await _save();
    await Notifier.instance.requestPermissions();
    _doneReported.remove(m);
    HomeAssistant.instance.report(m, run);
    await Notifier.instance.scheduleRun(run);
    await _showLive(run);
    return run;
  }

  /// Schon früher fertig (z. B. Maschine war schneller).
  Future<void> finishNow(Machine m) async {
    final r = _runs[m];
    if (r == null) return;
    final now = DateTime.now();
    _runs[m] = Run(
      machine: m,
      programName: r.programName,
      start: r.start.isAfter(now) ? now : r.start,
      end: now,
    );
    notifyListeners();
    await _save();
    _doneReported.add(m);
    HomeAssistant.instance.report(m, _runs[m]);
    // Plant nur noch das „noch nicht abgeholt?“ in 15 Minuten.
    await Notifier.instance.scheduleRun(_runs[m]!);
    await WashLive.stop(m.name);
  }

  /// Timer abbrechen (falsch gestartet).
  Future<void> stop(Machine m) => _clear(m);

  /// Wäsche abgeholt – Slot wieder frei.
  Future<void> collect(Machine m) => _clear(m);

  Future<void> snooze(Machine m) => Notifier.instance.snooze(m, const Duration(minutes: 5));

  Future<void> _clear(Machine m) async {
    _runs.remove(m);
    _doneReported.remove(m);
    notifyListeners();
    HomeAssistant.instance.report(m, null);
    await _save();
    await Notifier.instance.cancel(m);
    await WashLive.stop(m.name);
  }

  /// Zeit abgelaufen, während die App offen ist → HA „finished“ melden.
  void _reportFinished() {
    final now = DateTime.now();
    for (final r in _runs.values) {
      if (r.isDone(now) && _doneReported.add(r.machine)) {
        HomeAssistant.instance.report(r.machine, r);
      }
    }
  }

  static Future<void> _showLive(Run r) => WashLive.start(
        machine: r.machine.name,
        title: t.machineRunningTitle(r.machine),
        program: r.programName,
        start: r.start,
        end: r.end,
      );

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Macht den Store im Widget-Baum verfügbar und baut bei Änderungen neu.
class StoreScope extends InheritedNotifier<WashStore> {
  const StoreScope({super.key, required WashStore store, required super.child}) : super(notifier: store);

  static WashStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static WashStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
