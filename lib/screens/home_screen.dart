import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/doodle.dart';
import '../widgets/doodles.dart';
import 'machine_flow.dart';
import 'programs_sheet.dart';
import 'start_screen.dart';
import '../l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final wash = store.run(Machine.wash);
    final dry = store.run(Machine.dry);
    final running = [wash, dry].whereType<Run>().length;
    final anyDone = [wash, dry].whereType<Run>().any((r) => r.isDone(now));

    final (headline, sub, footer) = switch ((running, anyDone)) {
      (_, true) => (t.homeDoneTitle, t.homeDoneBody, t.tagSocks),
      (2, _) => (t.homeBothTitle, t.homeBothBody, t.tagTwo),
      (1, _) => (
          t.homeOneTitle,
          t.homeOneBody(wash != null),
          t.tagSocks
        ),
      _ => (t.homeIdleTitle, t.homeIdleBody, t.tagSocks),
    };

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('wa:sh', style: font(size: 20, weight: FontWeight.w700, spacing: -0.6)),
                  const Spacer(),
                  RoundIcon(
                    icon: Icons.tune,
                    label: t.myPrograms,
                    onTap: () => showProgramsSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Text(headline, style: display(56)),
              const SizedBox(height: 14),
              Text(sub, style: font(size: 17, height: 1.35, color: C.sub)),
              const SizedBox(height: 32),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final h = math.min(box.maxHeight, 360.0);
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: h,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _MachineTile(machine: Machine.wash, run: wash, now: now)),
                          const SizedBox(width: 14),
                          Expanded(child: _MachineTile(machine: Machine.dry, run: dry, now: now)),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              Text(footer, textAlign: TextAlign.center, style: font(size: 15, color: C.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eine Maschine = eine Kachel. Frei → starten, läuft → Restzeit, fertig → abholen.
class _MachineTile extends StatelessWidget {
  const _MachineTile({required this.machine, required this.run, required this.now});

  final Machine machine;
  final Run? run;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final r = run;
    final open = r == null
        ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StartScreen(machine: machine)))
        : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MachineFlow(machine: machine)));

    return Material(
      color: C.machine(machine),
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: open,
        child: Semantics(
          button: true,
          label: r == null
              ? t.startMachine(machine)
              : r.isDone(now)
                  ? t.machineDoneCollect(machine)
                  : t.machineRunningFor(machine, r.remaining(now).inMinutes),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: r == null
                    ? _Idle(key: const ValueKey('idle'), machine: machine)
                    : _Busy(key: const ValueKey('busy'), run: r, now: now),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(machine.verb, style: font(size: 26, weight: FontWeight.w600, height: 1, spacing: -0.8)),
        const SizedBox(height: 3),
        Text(t.idle, style: font(size: 13, color: C.sub)),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Doodle(
                machine == Machine.wash ? washerTile(running: false) : dryerTile(running: false),
                width: 124,
              ),
            ),
          ),
        ),
        Container(
          height: 44,
          decoration: ShapeDecoration(color: C.ink, shape: StadiumBorder()),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(t.start, style: font(size: 15, weight: FontWeight.w600, color: C.white)),
            const SizedBox(width: 8),
            Icon(Icons.add, size: 18, color: C.white),
          ]),
        ),
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy({super.key, required this.run, required this.now});

  final Run run;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final done = run.isDone(now);
    final rem = run.remaining(now);
    final (big, unit) = done
        ? (t.done, '')
        : rem.inMinutes >= 60
            ? ('${rem.inHours}:${(rem.inMinutes % 60).toString().padLeft(2, '0')}', t.hoursUnit)
            : ('${math.max(1, rem.inMinutes + (rem.inSeconds % 60 > 0 ? 1 : 0))}', t.minutesUnit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: _Chip(text: done ? t.collectExcl : t.runningChip(run.machine))),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Doodle(
                run.machine == Machine.wash ? washerTile(running: !done) : dryerTile(running: !done),
                width: 104,
              ),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(big, style: font(size: 44, weight: FontWeight.w600, height: 1, spacing: -1.7, features: tabular)),
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(unit, style: font(size: 15, weight: FontWeight.w600)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 4,
            child: Stack(children: [
              Container(color: C.ink.withAlpha(38)),
              FractionallySizedBox(widthFactor: run.progress(now), child: Container(color: C.ink)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: done ? t.since : t.doneAtLabel, style: font(size: 13, color: C.sub)),
                TextSpan(text: formatClock(run.end), style: font(size: 13, weight: FontWeight.w600)),
              ]),
              maxLines: 1,
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: C.ink, shape: BoxShape.circle),
            child: Icon(Icons.arrow_forward, size: 16, color: C.white),
          ),
        ]),
      ],
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.text});

  final String text;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(color: C.white.withAlpha(166), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.25).animate(_c),
          child: Container(width: 7, height: 7, decoration: BoxDecoration(color: C.ink, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 6),
        Text(widget.text, style: font(size: 12, weight: FontWeight.w600)),
      ]),
    );
  }
}
