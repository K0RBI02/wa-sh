import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/doodle.dart';
import '../widgets/doodles.dart';
import 'start_screen.dart';

/// Schritt 2 (läuft) und Schritt 3 (abholen) für eine Maschine.
/// Wechselt von selbst, sobald die Zeit um ist.
class MachineFlow extends StatelessWidget {
  const MachineFlow({super.key, required this.machine});

  final Machine machine;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final run = store.run(machine);
    final now = DateTime.now();

    if (run == null) {
      // Abgeholt oder gestoppt (evtl. von woanders) – zurück zum Start.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).maybePop();
        }
      });
      return const Scaffold(backgroundColor: C.bg);
    }

    final done = run.isDone(now);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: done ? C.peach : C.green,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: done
                  ? _DoneView(key: const ValueKey('done'), run: run, now: now)
                  : _RunningView(key: const ValueKey('running'), run: run, now: now),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunningView extends StatelessWidget {
  const _RunningView({super.key, required this.run, required this.now});

  final Run run;
  final DateTime now;

  String _countdown() {
    final r = run.remaining(now);
    final h = r.inHours;
    final m = r.inMinutes % 60;
    final s = r.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${r.inMinutes}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final m = run.machine;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepBar(active: 1, progress: run.progress(now)),
        const SizedBox(height: 32),
        Text('Ruhig\nBleiben', style: display()),
        Expanded(
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: Doodle(machineRunning(C.green), width: 280)),
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          children: [
            Text(_countdown(), style: font(size: 52, weight: FontWeight.w600, height: 1, spacing: -1.5, features: tabular)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('fertig um ${formatClock(run.end)}', style: font(size: 15, color: C.sub)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('${m.label} · ${run.programName}', style: font(size: 14, color: C.sub)),
        const SizedBox(height: 14),
        RichBody(
          '${m == Machine.wash ? 'Deine Wäsche dreht ihre Runden' : 'Der Trockner pustet fleißig'}. '
          'Wir **erinnern dich ${reminderLead.inMinutes} Minuten vorher** – du musst nicht in den Keller schauen.',
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            PillButton(
              label: 'Zur Übersicht',
              onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            const SizedBox(width: 20),
            Tap(
              onTap: () {
                HapticFeedback.lightImpact();
                store.finishNow(m);
              },
              radius: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Text('Schon fertig', style: font(size: 15, weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DoneView extends StatefulWidget {
  const _DoneView({super.key, required this.run, required this.now});

  final Run run;
  final DateTime now;

  @override
  State<_DoneView> createState() => _DoneViewState();
}

class _DoneViewState extends State<_DoneView> {
  bool _snoozed = false;

  String _since() {
    final d = widget.now.difference(widget.run.end);
    if (d.inMinutes < 1) return 'gerade eben';
    if (d.inHours < 1) return 'seit ${d.inMinutes} Min';
    return 'seit ${d.inHours} Std ${d.inMinutes % 60} Min';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final m = widget.run.machine;
    final dryerFree = m == Machine.wash && store.run(Machine.dry) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StepBar(active: 2),
        const SizedBox(height: 32),
        Text('Ab in den\nKeller', style: display()),
        Expanded(
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: Doodle(laundryDone(C.peach), width: 280)),
          ),
        ),
        RichBody(
          '${m == Machine.wash ? 'Deine Wäsche' : 'Der Trockner'} ist **fertig**. '
          'Hol sie raus, bevor sich der Nachbar deine Lieblingssocken ausleiht.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: C.white.withAlpha(140), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            const Icon(Icons.alarm, size: 22, color: C.ink),
            const SizedBox(width: 12),
            Text('Fertig ', style: font(size: 14, color: C.sub)),
            Text(_since(), style: font(size: 14, weight: FontWeight.w600)),
          ]),
        ),
        if (dryerFree) ...[
          const SizedBox(height: 10),
          Material(
            color: C.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                // Erst weiter navigieren, dann den Slot freigeben – sonst
                // schließt sich dieser Screen vorher von selbst.
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StartScreen(machine: Machine.dry)),
                );
                store.collect(m);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.air, size: 26, color: C.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Weiter in den Trockner', style: font(size: 15, weight: FontWeight.w600)),
                      Text('Trockner-Timer gleich mitstarten', style: font(size: 13, color: C.sub)),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward, size: 20, color: C.ink),
                ]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            PillButton(
              label: 'Abgeholt',
              onTap: () {
                HapticFeedback.mediumImpact();
                store.collect(m);
              },
            ),
            const SizedBox(width: 16),
            Flexible(
              child: SideLink(
                question: 'Gerade keine Zeit?',
                action: _snoozed ? 'Erinnere dich in 5 Min' : 'In 5 Min erinnern',
                onTap: () {
                  store.snooze(m);
                  setState(() => _snoozed = true);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
