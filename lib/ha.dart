import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'models.dart';

/// Verbindung zur Home-Assistant-Integration „wa:sh“ (custom_components/wash).
///
/// Kopplung: In HA „Integration hinzufügen → wa:sh“ zeigt einen Code wie
/// `K7Q-2M9`. Die App schickt ihn an `/api/wash/pair` und bekommt dafür die
/// Webhook-Adresse – kein Token, kein Zwischenserver.
///
/// Danach meldet die App jeden Wechsel (Start, „Schon fertig“, Abgeholt) an
/// den Webhook. Das Ende rechnet die Integration selbst aus, HA weiß also
/// auch ohne Handy, wann die Wäsche fertig ist.
///
/// Ist HA nicht erreichbar, wird der letzte Stand gemerkt und später erneut
/// gesendet. Mit Nabu Casa gibt es zusätzlich eine Cloud-Adresse als Ausweichweg.
class HomeAssistant extends ChangeNotifier {
  HomeAssistant._(this._prefs, this._secure) {
    _url = _prefs.getString(_kUrl) ?? '';
    _name = _prefs.getString(_kName) ?? '';
  }

  static const _kUrl = 'ha.url';
  static const _kName = 'ha.name';
  static const _kWebhook = 'ha.webhook';
  static const _kCloud = 'ha.cloudhook';
  static const _kLegacyToken = 'ha.token';

  static HomeAssistant? _instance;
  static HomeAssistant get instance => _instance!;

  /// [secure] und [send] lassen sich in Tests ersetzen.
  static Future<HomeAssistant> load({
    FlutterSecureStorage secure = const FlutterSecureStorage(),
    Sender? send,
  }) async {
    final ha = HomeAssistant._(await SharedPreferences.getInstance(), secure);
    if (send != null) ha._sendJson = send;
    _instance = ha;
    // Webhook-ID ist das Geheimnis → verschlüsselt (Android Keystore / iOS Keychain).
    try {
      ha._webhook = await secure.read(key: _kWebhook) ?? '';
      ha._cloud = await secure.read(key: _kCloud) ?? '';
      // Reste der alten Token-Anbindung (0.2) entfernen.
      await secure.delete(key: _kLegacyToken);
    } catch (e) {
      debugPrint('Kopplung nicht lesbar: $e');
    }
    await ha._prefs.remove(_kLegacyToken);
    ha._retry = Timer.periodic(const Duration(minutes: 1), (_) => ha.sync());
    return ha;
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  late Sender _sendJson = _httpSend;
  String _url = '';
  String _name = '';
  String _webhook = '';
  String _cloud = '';
  Timer? _retry;
  final Map<Machine, Map<String, Object?>> _pending = {};

  /// Stand aus HA übernehmen (z. B. dort gestartet oder abgeholt) – setzt der Store.
  void Function(List<RemoteState> machines)? onRemote;

  /// Die Lieblingsprogramme für die Auswahl in HA – liefert der Store.
  Map<String, Object?> Function()? programsProvider;

  /// Letztes Ergebnis für die Anzeige in den Einstellungen.
  String? lastError;
  DateTime? lastSuccess;

  String get url => _url;

  /// Name des Eintrags in HA, z. B. „Waschküche“.
  String get name => _name;
  bool get paired => _url.isNotEmpty && _webhook.isNotEmpty;

  /// „homeassistant.local:8123/“ → „http://homeassistant.local:8123“.
  static String normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    return u;
  }

  /// Mit dem Code aus HA koppeln. `null` = geklappt, sonst Fehlertext.
  Future<String?> pair({required String url, required String code}) async {
    final u = normalizeUrl(url);
    final c = code.trim();
    if (u.isEmpty) return t.haErrNoAddress;
    if (c.isEmpty) return t.haErrNoCode;
    try {
      final res = await _sendJson('$u/api/wash/pair', {'code': c});
      switch (res.status) {
        case 200:
          break;
        case 404:
          // 404 kommt auch, wenn die Integration gar nicht installiert ist.
          return res.body is Map ? t.haErrBadCode : t.haErrNoIntegration;
        case 429:
          return t.haErrTooMany;
        default:
          return t.haErrStatus(res.status);
      }
      final body = res.body;
      if (body is! Map || body['webhook_id'] is! String) return t.haErrUnexpected;
      _url = u;
      _name = (body['name'] as String?) ?? 'Home Assistant';
      _webhook = body['webhook_id'] as String;
      _cloud = (body['cloudhook_url'] as String?) ?? '';
      await _save();
      lastError = null;
      lastSuccess = DateTime.now();
      notifyListeners();
      await sync();
      return null;
    } catch (e) {
      return _describe(e);
    }
  }

  /// Verbindung prüfen. `null` = erreichbar, sonst Fehlertext.
  Future<String?> test() async {
    if (!paired) return t.haErrNotPaired;
    final (err, _) = await _post({'type': 'ping', if (programsProvider != null) 'programs': programsProvider!()});
    lastError = err;
    if (err == null) lastSuccess = DateTime.now();
    notifyListeners();
    if (err == null) await _flush();
    return err;
  }

  /// Kopplung in der App aufheben (der Eintrag in HA bleibt, bis man ihn dort löscht).
  Future<void> unpair() async {
    _webhook = '';
    _cloud = '';
    _name = '';
    _pending.clear();
    lastError = null;
    lastSuccess = null;
    await _save();
    notifyListeners();
  }

  /// Neuen Stand einer Maschine melden (`run == null` → frei).
  Future<void> report(Machine m, Run? run, {DateTime? changed}) async {
    _pending[m] = payloadFor(m, run, changed: changed);
    await _flush();
  }

  bool _syncing = false;

  /// Abgleich mit HA: eigene Änderungen senden, dann den Stand aus HA holen
  /// (dort gestartet oder abgeholt?) und die Programme für die Auswahl melden.
  Future<void> sync() async {
    if (!paired || _syncing) return;
    _syncing = true;
    try {
      await _flush();
      if (_pending.isNotEmpty) return; // nicht erreichbar
      final (err, _) = await _post({'type': 'sync', if (programsProvider != null) 'programs': programsProvider!()});
      lastError = err;
      if (err == null) lastSuccess = DateTime.now();
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  void _takeMachines(Object? body) {
    if (body is! Map || body['machines'] is! Map) return;
    final list = <RemoteState>[];
    for (final e in (body['machines'] as Map).entries) {
      final r = RemoteState.fromJson('${e.key}', e.value);
      if (r != null) list.add(r);
    }
    if (list.isNotEmpty) onRemote?.call(list);
  }

  Future<void> _flush() async {
    if (!paired || _pending.isEmpty) return;
    for (final m in List.of(_pending.keys)) {
      final p = _pending[m]!;
      final (err, _) = await _post(p);
      if (err != null) {
        lastError = err;
        break; // nicht erreichbar – später nochmal
      }
      if (identical(_pending[m], p)) _pending.remove(m);
      lastSuccess = DateTime.now();
      lastError = null;
    }
    notifyListeners();
  }

  /// Erst lokal, dann (falls vorhanden) über Nabu Casa. Antwortet HA mit dem
  /// aktuellen Stand, wird er übernommen.
  Future<(String?, Object?)> _post(Map<String, Object?> body) async {
    final targets = ['$_url/api/webhook/$_webhook', if (_cloud.isNotEmpty) _cloud];
    String? err;
    for (final target in targets) {
      try {
        final res = await _sendJson(target, body);
        if (res.status >= 200 && res.status < 300) {
          _takeMachines(res.body);
          return (null, res.body);
        }
        err = res.status == 404 || res.status == 405
            ? t.haErrRemoved
            : t.haErrStatus(res.status);
        if (res.status < 500) return (err, null); // kein Netzproblem – Ausweichweg hilft nicht
      } catch (e) {
        err = _describe(e);
      }
    }
    return (err, null);
  }

  /// Was an HA geht – öffentlich nur für Tests.
  @visibleForTesting
  Map<String, Object?> payloadFor(Machine m, Run? run, {DateTime? now, DateTime? changed}) {
    now ??= DateTime.now();
    return {
      if (changed != null) 'changed': changed.toUtc().toIso8601String(),
      'type': 'update',
      'machine': m == Machine.wash ? 'wash' : 'dry',
      'state': run == null ? 'idle' : (run.isDone(now) ? 'finished' : 'running'),
      if (run != null) ...{
        'program': run.programName,
        'start': run.start.toUtc().toIso8601String(),
        'end': run.end.toUtc().toIso8601String(),
      },
    };
  }

  Future<void> _save() async {
    await _prefs.setString(_kUrl, _url);
    await _prefs.setString(_kName, _name);
    try {
      for (final (k, v) in [(_kWebhook, _webhook), (_kCloud, _cloud)]) {
        if (v.isEmpty) {
          await _secure.delete(key: k);
        } else {
          await _secure.write(key: k, value: v);
        }
      }
    } catch (e) {
      debugPrint('Kopplung nicht speicherbar: $e');
    }
  }

  static Future<HaResponse> _httpSend(String url, Object body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.postUrl(Uri.parse(url)).timeout(const Duration(seconds: 10));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
      // Großzügig: Beim Koppeln wartet HA, bis der Eintrag angelegt ist.
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await res.transform(utf8.decoder).join();
      Object? parsed;
      try {
        parsed = text.isEmpty ? null : jsonDecode(text);
      } on FormatException {
        parsed = text;
      }
      return HaResponse(res.statusCode, parsed);
    } finally {
      client.close(force: true);
    }
  }

  static String _describe(Object e) {
    if (e is SocketException || e is TimeoutException) return t.haErrUnreachable;
    if (e is HandshakeException) return t.haErrCert;
    if (e is FormatException || e is ArgumentError) return t.haErrBadAddress;
    return t.haErrOther(e);
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }
}

/// Antwort von HA: Status und (falls JSON) der Inhalt.
class HaResponse {
  const HaResponse(this.status, this.body);
  final int status;
  final Object? body;
}

typedef Sender = Future<HaResponse> Function(String url, Object body);

/// Stand einer Maschine laut Home Assistant.
class RemoteState {
  const RemoteState({
    required this.machine,
    required this.state,
    required this.changed,
    this.program,
    this.start,
    this.end,
  });

  final Machine machine;

  /// `idle`, `running` oder `finished`.
  final String state;
  final DateTime changed;
  final String? program;
  final DateTime? start;
  final DateTime? end;

  static RemoteState? fromJson(String machine, Object? raw) {
    if (raw is! Map) return null;
    final m = Machine.values.where((x) => x.name == machine).firstOrNull;
    final changed = DateTime.tryParse('${raw['changed']}');
    final state = raw['state'];
    if (m == null || changed == null || state is! String) return null;
    DateTime? time(String key) => raw[key] is String ? DateTime.tryParse(raw[key] as String)?.toLocal() : null;
    return RemoteState(
      machine: m,
      state: state,
      changed: changed.toLocal(),
      program: raw['program'] as String?,
      start: time('start'),
      end: time('end'),
    );
  }
}
