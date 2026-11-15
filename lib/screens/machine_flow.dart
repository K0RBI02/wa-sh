import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/doodle.dart';
import '../widgets/doodles.dart';
import 'start_screen.dart';
import '../l10n.dart';

/// Dieser Screen ist eine Pastell-Insel: immer die hellen Farben, auch im Dunkelmodus.
const c = Pal.day;

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
      return Scaffold(backgroundColor: c.bg);
    }

    final done = run.isDone(now);
    return pastelScreen(AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: done ? c.peach : c.green,
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
    ));
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
        Text(t.relaxTitle, style: display(58, c.ink)),
        Expanded(
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: Doodle(machineRunning(c.green), width: 280)),
          ),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 10,
          children: [
            Text(_countdown(), style: font(size: 52, weight: FontWeight.w600, height: 1, spacing: -1.5, features: tabular, color: c.ink)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(t.finishesAt(formatClock(run.end)), style: font(size: 15, color: c.sub)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('${m.label} · ${run.programName}', style: font(size: 14, color: c.sub)),
        const SizedBox(height: 14),
        RichBody(t.runningBody(m, reminderLead.inMinutes)),
        const SizedBox(height: 28),
        Row(
          children: [
            PillButton(
              label: t.toOverview,
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
                child: Text(t.alreadyDone, style: font(size: 15, weight: FontWeight.w600, color: c.ink)),
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
    if (d.inMinutes < 1) return t.justNow;
    if (d.inHours < 1) return t.sinceMinutes(d.inMinutes);
    return t.sinceHours(d.inHours, d.inMinutes % 60);
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
        Text(t.basementTitle, style: display(58, c.ink)),
        Expanded(
          child: Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: Doodle(laundryDone(c.peach), width: 280)),
          ),
        ),
        RichBody(t.doneBody(m)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: c.white.withAlpha(140), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Icon(Icons.alarm, size: 22, color: c.ink),
            const SizedBox(width: 12),
            Text(t.doneSpace, style: font(size: 14, color: c.sub)),
            Text(_since(), style: font(size: 14, weight: FontWeight.w600, color: c.ink)),
          ]),
        ),
        if (dryerFree) ...[
          const SizedBox(height: 10),
          Material(
            color: c.white,
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
                  Icon(Icons.air, size: 26, color: c.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.onToDryer, style: font(size: 15, weight: FontWeight.w600, color: c.ink)),
                      Text(t.onToDryerSub, style: font(size: 13, color: c.sub)),
                    ]),
                  ),
                  Icon(Icons.arrow_forward, size: 20, color: c.ink),
                ]),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            PillButton(
              label: t.collected,
              onTap: () {
                HapticFeedback.mediumImpact();
                store.collect(m);
              },
            ),
            const SizedBox(width: 16),
            Flexible(
              child: SideLink(
                question: t.noTime,
                action: _snoozed ? t.willRemind5 : t.remind5,
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
