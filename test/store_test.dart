import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wash/ha.dart';
import 'package:wash/models.dart';
import 'package:wash/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WashStore store;

  Future<void> boot([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    await HomeAssistant.load();
    store = await WashStore.load();
  }

  tearDown(() {
    store.dispose();
    HomeAssistant.instance.dispose();
  });

  test('Waschmaschine und Trockner laufen unabhängig voneinander', () async {
    await boot();
    await store.start(Machine.wash, 'Bunt 40°', 105);
    await store.start(Machine.dry, 'Baumwolle', 100);

    expect(store.run(Machine.wash)!.programName, 'Bunt 40°');
    expect(store.run(Machine.dry)!.total, const Duration(minutes: 100));

    await store.collect(Machine.wash);
    expect(store.run(Machine.wash), isNull);
    expect(store.run(Machine.dry), isNotNull, reason: 'Trockner läuft weiter');
  });

  test('„Schon fertig“ beendet sofort, die Wäsche bleibt bis zum Abholen', () async {
    await boot();
    await store.start(Machine.wash, 'Kurz', 30);
    await store.finishNow(Machine.wash);

    final run = store.run(Machine.wash);
    expect(run, isNotNull);
    expect(run!.isDone(DateTime.now()), isTrue);
  });

  test('Timer stoppen gibt die Maschine frei', () async {
    await boot();
    await store.start(Machine.dry, 'Extra', 120);
    await store.stop(Machine.dry);
    expect(store.run(Machine.dry), isNull);
  });

  test('ein neuer Start ersetzt den alten Timer derselben Maschine', () async {
    await boot();
    await store.start(Machine.wash, 'Bunt 40°', 105);
    await store.start(Machine.wash, 'Eigene Zeit', 45);
    expect(store.run(Machine.wash)!.programName, 'Eigene Zeit');
    expect(store.run(Machine.wash)!.total, const Duration(minutes: 45));
  });

  test('laufende Timer überstehen einen Neustart der App', () async {
    await boot();
    final run = await store.start(Machine.wash, 'Bunt 40°', 105);
    store.dispose();
    HomeAssistant.instance.dispose();

    // Gleicher Speicher, neue Instanz – wie nach einem App-Neustart.
    await HomeAssistant.load();
    store = await WashStore.load();
    final back = store.run(Machine.wash);
    expect(back, isNotNull);
    expect(back!.end, run.end);
    expect(back.programName, 'Bunt 40°');
  });

  test('geänderte Programme werden gespeichert', () async {
    await boot();
    store.updateProgram(Machine.dry, 1, const Program('Wolle', 45));
    await Future<void>.delayed(Duration.zero);
    store.dispose();
    HomeAssistant.instance.dispose();

    await HomeAssistant.load();
    store = await WashStore.load();
    expect(store.programs(Machine.dry)[1].name, 'Wolle');
    expect(store.programs(Machine.dry)[1].minutes, 45);
    expect(store.programs(Machine.wash)[0].name, defaultPrograms[Machine.wash]![0].name);
  });

  test('kaputte gespeicherte Daten führen zu Standardwerten statt Absturz', () async {
    await boot({'programs.v1': 'kaputt', 'runs.v1': '[{'});
    expect(store.programs(Machine.wash)[0].name, defaultPrograms[Machine.wash]![0].name);
    expect(store.run(Machine.wash), isNull);
    expect(store.run(Machine.dry), isNull);
  });
}
