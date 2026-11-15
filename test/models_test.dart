import 'package:flutter_test/flutter_test.dart';
import 'package:wash/models.dart';

void main() {
  final start = DateTime(2026, 11, 15, 12, 0);
  final run = Run(
    machine: Machine.wash,
    programName: 'Bunt 40°',
    start: start,
    end: start.add(const Duration(minutes: 100)),
  );

  group('Run', () {
    test('Restzeit und Fortschritt', () {
      final halfway = start.add(const Duration(minutes: 50));
      expect(run.remaining(halfway), const Duration(minutes: 50));
      expect(run.progress(halfway), closeTo(0.5, 0.001));
      expect(run.isDone(halfway), isFalse);
    });

    test('nach dem Ende: Restzeit 0, Fortschritt 1, fertig', () {
      final later = start.add(const Duration(hours: 3));
      expect(run.remaining(later), Duration.zero);
      expect(run.progress(later), 1.0);
      expect(run.isDone(later), isTrue);
    });

    test('vor dem Start: Fortschritt 0', () {
      expect(run.progress(start.subtract(const Duration(minutes: 5))), 0.0);
    });

    test('genau am Ende gilt als fertig', () {
      expect(run.isDone(run.end), isTrue);
    });

    test('Laufzeit 0 führt nicht zu Division durch 0', () {
      final zero = Run(machine: Machine.dry, programName: 'x', start: start, end: start);
      expect(zero.progress(start), 1.0);
    });

    test('JSON hin und zurück', () {
      final back = Run.fromJson(run.toJson());
      expect(back.machine, run.machine);
      expect(back.programName, run.programName);
      expect(back.start, run.start);
      expect(back.end, run.end);
    });
  });

  group('Program', () {
    test('JSON hin und zurück', () {
      const p = Program('Handtücher 60°', 130);
      final back = Program.fromJson(p.toJson());
      expect(back.name, p.name);
      expect(back.minutes, p.minutes);
    });

    test('copyWith ändert nur das Angegebene', () {
      const p = Program('Bunt 40°', 105);
      expect(p.copyWith(minutes: 90).name, 'Bunt 40°');
      expect(p.copyWith(name: 'Bunt').minutes, 105);
    });

    test('je Maschine zwei Standardprogramme', () {
      for (final m in Machine.values) {
        expect(defaultPrograms[m], hasLength(2));
      }
    });
  });

  group('Formatierung', () {
    test('Dauer', () {
      expect(formatDuration(105), '1:45 Std');
      expect(formatDuration(60), '1:00 Std');
      expect(formatDuration(15), '0:15 Std');
    });

    test('Uhrzeit', () {
      expect(formatClock(DateTime(2026, 1, 1, 9, 5)), '09:05');
      expect(formatClock(DateTime(2026, 1, 1, 23, 59)), '23:59');
    });
  });
}
