import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native „läuft“-Anzeige für wa:sh.
///
/// * Android: Vordergrund-Dienst mit Balken, Countdown und zwei Buttons;
///   auf Android 16 als Live Update mit Chip in der Statusleiste.
/// * iOS: Live Activity auf dem Sperrbildschirm und in der Dynamic Island
///   (ab iOS 16.2, braucht die Widget-Erweiterung – siehe README).
class WashLive {
  WashLive._();

  static const _channel = MethodChannel('wash/live');
  static bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Tipp auf die Anzeige oder einen ihrer Buttons.
  /// [action] ist `null`, `'finish'` oder `'overview'`.
  static void Function(String machine, String? action)? onOpen;

  static void init() {
    if (!_supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') _dispatch(call.arguments);
    });
  }

  /// Falls die App über die Anzeige gestartet wurde: jetzt weiterleiten.
  static Future<void> consumeLaunch() async {
    if (!_supported) return;
    try {
      _dispatch(await _channel.invokeMethod<Object?>('launchAction'));
    } catch (e) {
      debugPrint('WashLive: $e');
    }
  }

  static Future<void> start({
    required String machine,
    required String title,
    required String program,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('start', {
        'machine': machine,
        'title': title,
        'program': program,
        'start': start.millisecondsSinceEpoch,
        'end': end.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('WashLive: $e');
    }
  }

  static Future<void> stop(String machine) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('stop', {'machine': machine});
    } catch (e) {
      debugPrint('WashLive: $e');
    }
  }

  /// Stand einer Maschine fürs Widget auf dem Startbildschirm (Android).
  /// [state]: `idle`, `running` oder `finished`.
  static Future<void> updateWidget({
    required String machine,
    required String state,
    String? program,
    DateTime? start,
    DateTime? end,
  }) async {
    if (!_supported || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('widget', {
        'machine': machine,
        'state': state,
        'program': program,
        'start': start?.millisecondsSinceEpoch ?? 0,
        'end': end?.millisecondsSinceEpoch ?? 0,
      });
    } catch (e) {
      debugPrint('WashLive: $e');
    }
  }

  /// Öffnet die Benachrichtigungs-Einstellungen der App im System.
  static Future<void> openNotificationSettings() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } on PlatformException catch (e) {
      debugPrint('Einstellungen nicht geöffnet: $e');
    }
  }

  /// `wash://start?machine=wash&program=1` (oder `&minutes=90&name=…`) –
  /// Link bzw. NFC-Sticker an der Maschine.
  static void Function(String machine, {int? program, int? minutes, String? name})? onStartLink;

  static void _dispatch(Object? data) {
    if (data is! Map) return;
    final machine = data['machine'];
    if (machine is! String) return;
    final action = data['action'];
    if (action == 'start') {
      onStartLink?.call(
        machine,
        program: int.tryParse('${data['program']}'),
        minutes: int.tryParse('${data['minutes']}'),
        name: data['name'] is String ? data['name'] as String : null,
      );
      return;
    }
    onOpen?.call(machine, action is String && action.isNotEmpty ? action : null);
  }
}
