import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wash/ha.dart';
import 'package:wash/models.dart';

/// Ersetzt HTTP: merkt sich Anfragen und antwortet nach Vorgabe.
class FakeHa {
  final calls = <(String, Object)>[];
  HaResponse Function(String url, Object body) answer = (_, _) => const HaResponse(200, {'ok': true});

  Future<HaResponse> call(String url, Object body) async {
    calls.add((url, body));
    return answer(url, body);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomeAssistant ha;
  late FakeHa fake;
  final start = DateTime(2026, 11, 15, 12, 0);
  final run = Run(
    machine: Machine.wash,
    programName: 'Bunt 40°',
    start: start,
    end: start.add(const Duration(minutes: 100)),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    fake = FakeHa();
    ha = await HomeAssistant.load(send: fake.call);
  });

  tearDown(() => ha.dispose());

  test('Adresse wird bereinigt', () {
    expect(HomeAssistant.normalizeUrl(' homeassistant.local:8123/ '), 'http://homeassistant.local:8123');
    expect(HomeAssistant.normalizeUrl('https://ha.example.org//'), 'https://ha.example.org');
  });

  test('Meldungen: frei, läuft, fertig', () {
    expect(ha.payloadFor(Machine.dry, null, now: start), {'type': 'update', 'machine': 'dry', 'state': 'idle'});
    final p = ha.payloadFor(Machine.wash, run, now: start.add(const Duration(minutes: 25)));
    expect(p['machine'], 'wash');
    expect(p['state'], 'running');
    expect(p['program'], 'Bunt 40°');
    expect(p['end'], run.end.toUtc().toIso8601String());
    expect(ha.payloadFor(Machine.wash, run, now: start.add(const Duration(hours: 2)))['state'], 'finished');
  });

  test('Koppeln mit Code', () async {
    fake.answer = (url, _) => url.endsWith('/api/wash/pair')
        ? const HaResponse(200, {'name': 'Waschküche', 'webhook_id': 'abc123', 'cloudhook_url': null})
        : const HaResponse(200, {'ok': true});

    expect(ha.paired, isFalse);
    expect(await ha.pair(url: 'ha.local:8123', code: 'k7q-2m9'), isNull);
    expect(ha.paired, isTrue);
    expect(ha.name, 'Waschküche');
    expect(fake.calls.first.$1, 'http://ha.local:8123/api/wash/pair');
    expect(fake.calls.first.$2, {'code': 'k7q-2m9'});

    await ha.report(Machine.wash, run);
    expect(fake.calls.last.$1, 'http://ha.local:8123/api/webhook/abc123');
    expect((fake.calls.last.$2 as Map)['state'], isNotNull);

    // Kopplung überlebt einen App-Neustart.
    final again = await HomeAssistant.load(send: fake.call);
    expect(again.paired, isTrue);
    expect(again.name, 'Waschküche');
    again.dispose();
  });

  test('Falscher Code und fehlende Integration', () async {
    fake.answer = (_, _) => const HaResponse(404, {'message': 'Code ungültig oder abgelaufen.'});
    expect(await ha.pair(url: 'ha.local', code: 'XXX'), 'Code ungültig oder abgelaufen');
    fake.answer = (_, _) => const HaResponse(404, '404: Not Found');
    expect(await ha.pair(url: 'ha.local', code: 'XXX'), 'wa:sh-Integration in HA nicht gefunden');
    expect(await ha.pair(url: '', code: 'XXX'), 'Adresse eintragen');
    expect(ha.paired, isFalse);
  });

  test('Lokal nicht erreichbar → Cloud-Adresse', () async {
    fake.answer = (url, _) => url.endsWith('/api/wash/pair')
        ? const HaResponse(200, {'name': 'W', 'webhook_id': 'id', 'cloudhook_url': 'https://hooks.nabu.casa/x'})
        : url.startsWith('https://hooks')
            ? const HaResponse(200, {'ok': true})
            : const HaResponse(502, null);
    await ha.pair(url: 'ha.local', code: 'C');
    fake.calls.clear();
    expect(await ha.test(), isNull);
    expect(fake.calls.map((c) => c.$1), ['http://ha.local/api/webhook/id', 'https://hooks.nabu.casa/x']);
  });

  test('Trennen', () async {
    fake.answer = (url, _) => url.endsWith('/pair')
        ? const HaResponse(200, {'name': 'W', 'webhook_id': 'id'})
        : const HaResponse(200, {'ok': true});
    await ha.pair(url: 'ha.local', code: 'C');
    await ha.unpair();
    expect(ha.paired, isFalse);
    expect(await ha.test(), 'Noch nicht gekoppelt');
  });
}
