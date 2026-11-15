import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wash/ha.dart';
import 'package:wash/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeAssistant ha;
  final start = DateTime(2026, 11, 15, 12, 0);
  final run = Run(
    machine: Machine.wash,
    programName: 'Bunt 40°',
    start: start,
    end: start.add(const Duration(minutes: 100)),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ha = await HomeAssistant.load();
  });

  tearDown(() => ha.dispose());

  Map<String, Object?> mainOf(Map<String, Object?> p) => p['main'] as Map<String, Object?>;
  Map<String, Object?> endOf(Map<String, Object?> p) => p['end'] as Map<String, Object?>;

  test('frei → idle, kein Zeitstempel', () {
    final p = ha.payloadFor(Machine.dry, null, now: start);
    expect(p['main_id'], 'sensor.wash_trockner');
    expect(p['end_id'], 'sensor.wash_trockner_fertig');
    expect(mainOf(p)['state'], 'idle');
    expect(endOf(p)['state'], 'unknown');
  });

  test('läuft → running, Zeitstempel „fertig um“ in UTC', () {
    final p = ha.payloadFor(Machine.wash, run, now: start.add(const Duration(minutes: 25)));
    expect(p['main_id'], 'sensor.wash_waschmaschine');
    expect(mainOf(p)['state'], 'running');
    final attrs = mainOf(p)['attributes'] as Map<String, Object?>;
    expect(attrs['program'], 'Bunt 40°');
    expect(attrs['progress'], 25);
    expect(endOf(p)['state'], run.end.toUtc().toIso8601String());
    expect((endOf(p)['attributes'] as Map)['device_class'], 'timestamp');
  });

  test('abgelaufen → finished, Zeitstempel wieder unknown', () {
    final p = ha.payloadFor(Machine.wash, run, now: start.add(const Duration(hours: 2)));
    expect(mainOf(p)['state'], 'finished');
    expect(endOf(p)['state'], 'unknown');
  });

  test('Adresse wird bereinigt', () async {
    await ha.configure(url: ' homeassistant.local:8123/ ', token: ' abc ');
    expect(ha.url, 'http://homeassistant.local:8123');
    expect(ha.token, 'abc');
    expect(ha.enabled, isTrue);

    await ha.configure(url: 'https://ha.example.org//', token: 'x');
    expect(ha.url, 'https://ha.example.org');
  });

  test('ohne URL oder Token ist die Anbindung aus', () async {
    await ha.configure(url: '', token: 'abc');
    expect(ha.enabled, isFalse);
    expect(await ha.test(), 'URL und Token eintragen');
  });
}
