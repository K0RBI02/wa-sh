import 'l10n.dart';

enum Machine { wash, dry }

extension MachineX on Machine {
  String get label => t.machine(this);
  String get shortLabel => t.machineShort(this);
  String get verb => t.verb(this);
  int get notificationBase => this == Machine.wash ? 100 : 200;
}

class Program {
  const Program(this.name, this.minutes);

  final String name;
  final int minutes;

  Program copyWith({String? name, int? minutes}) =>
      Program(name ?? this.name, minutes ?? this.minutes);

  Map<String, dynamic> toJson() => {'name': name, 'minutes': minutes};

  static Program fromJson(Map<String, dynamic> j) =>
      Program(j['name'] as String, (j['minutes'] as num).toInt());
}

/// Ein laufender (oder fertiger, aber noch nicht abgeholter) Durchgang.
class Run {
  const Run({required this.machine, required this.programName, required this.start, required this.end});

  final Machine machine;
  final String programName;
  final DateTime start;
  final DateTime end;

  Duration get total => end.difference(start);

  Duration remaining(DateTime now) {
    final r = end.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  bool isDone(DateTime now) => !now.isBefore(end);

  double progress(DateTime now) {
    final t = total.inSeconds;
    if (t <= 0) return 1;
    return (now.difference(start).inSeconds / t).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'machine': machine.name,
        'program': programName,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  static Run fromJson(Map<String, dynamic> j) => Run(
        machine: Machine.values.byName(j['machine'] as String),
        programName: j['program'] as String,
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
      );
}

/// Startprogramme für neue Installationen – in der Sprache des Geräts.
Map<Machine, List<Program>> get defaultPrograms => {for (final m in Machine.values) m: t.defaultPrograms(m)};

/// Wie viele Minuten vor Ende erinnert wird.
const reminderLead = Duration(minutes: 10);

String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')} ${t.hoursUnit}';
}

String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
