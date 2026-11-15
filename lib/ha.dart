import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Schickt den Zustand von Waschmaschine und Trockner an Home Assistant
/// (REST-API, Long-Lived Access Token).
///
/// Pro Maschine entstehen zwei Entitäten:
/// * `sensor.wash_waschmaschine` / `sensor.wash_trockner`
///   Zustand `idle` | `running` | `finished`, dazu Programm, Start, Ende, Fortschritt
/// * `sensor.wash_waschmaschine_fertig` / `sensor.wash_trockner_fertig`
///   Zeitstempel „fertig um“ – HA zeigt daraus selbst „in 14 Min.“ an und
///   Automationen können direkt darauf auslösen, auch wenn das Handy schläft.
///
/// Ist HA nicht erreichbar, wird der letzte Stand gemerkt und später erneut
/// gesendet (beim nächsten Wechsel, beim App-Start und jede Minute, solange
/// die App offen ist).
class HomeAssistant extends ChangeNotifier {
  HomeAssistant._(this._prefs, this._secure) {
    _url = _prefs.getString(_kUrl) ?? '';
  }

  static const _kUrl = 'ha.url';
  static const _kToken = 'ha.token';

  static HomeAssistant? _instance;
  static HomeAssistant get instance => _instance!;

  /// [secure] lässt sich in Tests ersetzen.
  static Future<HomeAssistant> load({FlutterSecureStorage secure = const FlutterSecureStorage()}) async {
    final ha = HomeAssistant._(await SharedPreferences.getInstance(), secure);
    _instance = ha;
    // Token liegt verschlüsselt (Android Keystore / iOS Keychain).
    try {
      ha._token = await secure.read(key: _kToken) ?? '';
    } catch (e) {
      debugPrint('Token nicht lesbar: $e');
    }
    // Ältere Versionen hatten den Token im normalen Speicher – umziehen.
    final legacy = ha._prefs.getString(_kToken);
    if (legacy != null) {
      if (ha._token.isEmpty) ha._token = legacy;
      await ha._storeToken();
      await ha._prefs.remove(_kToken);
    }
    ha._retry = Timer.periodic(const Duration(minutes: 1), (_) => ha._flush());
    return ha;
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  String _url = '';
  String _token = '';
  Timer? _retry;
  final Map<Machine, Map<String, Object?>> _pending = {};

  /// Letztes Ergebnis für die Anzeige in den Einstellungen.
  String? lastError;
  DateTime? lastSuccess;

  String get url => _url;
  String get token => _token;
  bool get enabled => _url.isNotEmpty && _token.isNotEmpty;

  Future<void> configure({required String url, required String token}) async {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.isNotEmpty && !u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    _url = u;
    _token = token.trim();
    await _prefs.setString(_kUrl, _url);
    await _storeToken();
    lastError = null;
    notifyListeners();
  }

  Future<void> _storeToken() async {
    try {
      if (_token.isEmpty) {
        await _secure.delete(key: _kToken);
      } else {
        await _secure.write(key: _kToken, value: _token);
      }
    } catch (e) {
      debugPrint('Token nicht speicherbar: $e');
    }
  }

  /// Prüft URL und Token. Gibt `null` zurück, wenn alles passt, sonst den Fehler.
  Future<String?> test() async {
    if (!enabled) return 'URL und Token eintragen';
    try {
      final res = await _send('GET', '/api/', null);
      if (res == 200) {
        lastSuccess = DateTime.now();
        lastError = null;
        notifyListeners();
        await _flush();
        return null;
      }
      return res == 401 ? 'Token ungültig' : 'HA antwortet mit Status $res';
    } catch (e) {
      return _describe(e);
    }
  }

  /// Neuen Stand einer Maschine melden (`run == null` → frei).
  Future<void> report(Machine m, Run? run) async {
    _pending[m] = payloadFor(m, run);
    await _flush();
  }

  Future<void> _flush() async {
    if (!enabled || _pending.isEmpty) return;
    for (final m in List.of(_pending.keys)) {
      final p = _pending[m]!;
      try {
        final a = await _send('POST', '/api/states/${p['main_id']}', p['main']);
        final b = await _send('POST', '/api/states/${p['end_id']}', p['end']);
        if (a >= 200 && a < 300 && b >= 200 && b < 300) {
          if (identical(_pending[m], p)) _pending.remove(m);
          lastSuccess = DateTime.now();
          lastError = null;
        } else {
          lastError = a == 401 || b == 401 ? 'Token ungültig' : 'HA antwortet mit Status $a';
        }
      } catch (e) {
        lastError = _describe(e);
        break; // nicht erreichbar – später nochmal
      }
    }
    notifyListeners();
  }

  /// Was an HA geht – öffentlich nur für Tests.
  @visibleForTesting
  Map<String, Object?> payloadFor(Machine m, Run? run, {DateTime? now}) {
    now ??= DateTime.now();
    final slug = m == Machine.wash ? 'waschmaschine' : 'trockner';
    final state = run == null ? 'idle' : (run.isDone(now) ? 'finished' : 'running');
    return {
      'main_id': 'sensor.wash_$slug',
      'end_id': 'sensor.wash_${slug}_fertig',
      'main': {
        'state': state,
        'attributes': {
          'friendly_name': 'wa:sh ${m.label}',
          'icon': m == Machine.wash ? 'mdi:washing-machine' : 'mdi:tumble-dryer',
          'program': run?.programName,
          'start': run?.start.toUtc().toIso8601String(),
          'end': run?.end.toUtc().toIso8601String(),
          'progress': run == null ? 0 : (run.progress(now) * 100).round(),
          'source': 'wa:sh',
        },
      },
      'end': {
        // Nur solange etwas läuft – sonst „unknown“, damit Automationen nicht falsch auslösen.
        'state': run == null || run.isDone(now) ? 'unknown' : run.end.toUtc().toIso8601String(),
        'attributes': {
          'friendly_name': 'wa:sh ${m.label} fertig um',
          'device_class': 'timestamp',
          'icon': 'mdi:timer-outline',
        },
      },
    };
  }

  Future<int> _send(String method, String path, Object? body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.openUrl(method, Uri.parse('$_url$path')).timeout(const Duration(seconds: 10));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      req.headers.contentType = ContentType.json;
      if (body != null) req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(const Duration(seconds: 10));
      await res.drain<void>();
      return res.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  static String _describe(Object e) {
    if (e is SocketException || e is TimeoutException) return 'HA nicht erreichbar';
    if (e is HandshakeException) return 'Zertifikat-Problem (https)';
    if (e is FormatException) return 'URL ungültig';
    return 'Fehler: $e';
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }
}
