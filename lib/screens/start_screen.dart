import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/doodle.dart';
import '../widgets/doodles.dart';
import 'machine_flow.dart';
import '../l10n.dart';

/// Schritt 1: Maschine und Programm wählen (oder eigene Zeit).
class StartScreen extends StatefulWidget {
  const StartScreen({super.key, required this.machine});

  final Machine machine;

  @override
  State<StartScreen> createState() => _StartScreenState();
}

const _custom = -1;
const _anim = Duration(milliseconds: 450);

class _StartScreenState extends State<StartScreen> {
  late Machine _machine = widget.machine;
  int _program = 0;
  int _customMin = 75;
  bool _editing = false;
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _bump() {
    _idle?.cancel();
    _idle = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _editing = false);
    });
  }

  void _pickMachine(Machine m) => _tick(() {
        _machine = m;
        _editing = false;
        _idle?.cancel();
      });

  void _pickProgram(int i) => _tick(() {
        _program = i;
        _editing = false;
        _idle?.cancel();
      });

  /// Kleines Klick-Gefühl bei jeder Auswahl.
  void _tick(VoidCallback fn) {
    HapticFeedback.selectionClick();
    setState(fn);
  }

  void _pickCustom() {
    HapticFeedback.selectionClick();
    setState(() {
      _program = _custom;
      _editing = true;
    });
    _bump();
  }

  void _stepCustom(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _customMin = (_customMin + delta).clamp(15, 300));
    _bump();
  }

  Future<void> _start() async {
    final store = StoreScope.read(context);
    final running = store.run(_machine);
    if (running != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(t.alreadyRunning(_machine), style: font(size: 20, weight: FontWeight.w600)),
          content: Text(t.replaceTimer, style: font(size: 15, color: C.sub)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.keep)),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(t.restart)),
          ],
        ),
      );
      if (ok != true) return;
    }
    final programs = store.programs(_machine);
    final name = _program == _custom ? t.customTime : programs[_program].name;
    final minutes = _program == _custom ? _customMin : programs[_program].minutes;
    await store.start(_machine, name, minutes);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MachineFlow(machine: _machine)));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final programs = store.programs(_machine);
    return Scaffold(
      backgroundColor: C.pink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepBar(active: 0),
              const SizedBox(height: 32),
              Text(t.startTitle, style: display()),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Doodle(
                        _machine == Machine.wash ? washerStart(C.pink) : dryerStart(C.pink),
                        key: ValueKey(_machine),
                        width: 280,
                      ),
                    ),
                  ),
                ),
              ),
              RichBody(t.startBody),
              const SizedBox(height: 18),
              _MachineToggle(selected: _machine, onPick: _pickMachine),
              const SizedBox(height: 10),
              _ProgramRow(
                programs: programs,
                selected: _program,
                editing: _editing,
                customMin: _customMin,
                onPick: _pickProgram,
                onCustom: _pickCustom,
                onStep: _stepCustom,
                onDone: () {
                  _idle?.cancel();
                  setState(() => _editing = false);
                },
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  PillButton(label: t.startTimer, onTap: _start),
                  const SizedBox(width: 16),
                  SideLink(question: t.changedMind, action: t.back, onTap: () => Navigator.of(context).maybePop()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Waschmaschine / Trockner – die Auswahl nimmt 75 % ein.
class _MachineToggle extends StatelessWidget {
  const _MachineToggle({required this.selected, required this.onPick});

  final Machine selected;
  final ValueChanged<Machine> onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 8.0;
      final w = (box.maxWidth - gap).floorToDouble();
      return Row(
        children: [
          for (final m in Machine.values) ...[
            if (m != Machine.values.first) const SizedBox(width: gap),
            _chip(m, (m == selected ? 0.75 : 0.25) * w),
          ],
        ],
      );
    });
  }

  Widget _chip(Machine m, double width) {
    final sel = m == selected;
    return AnimatedContainer(
      duration: _anim,
      curve: easeOut,
      width: width,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: sel ? C.ink : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: sel ? C.ink : C.ink.withAlpha(90), width: 1.5)),
      ),
      child: Tap(
        onTap: () => onPick(m),
        selected: sel,
        label: m.label,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(m == Machine.wash ? Icons.local_laundry_service_outlined : Icons.air,
                size: 20, color: sel ? C.white : C.ink),
            if (sel) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(m.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: font(size: 15, weight: FontWeight.w500, color: C.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Zwei gespeicherte Programme + „Eigene“. Auswahl = 50 %, beim Zeit-Eingeben
/// geht „Eigene“ kurz über die ganze Breite.
class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    required this.programs,
    required this.selected,
    required this.editing,
    required this.customMin,
    required this.onPick,
    required this.onCustom,
    required this.onStep,
    required this.onDone,
  });

  final List<Program> programs;
  final int selected;
  final bool editing;
  final int customMin;
  final ValueChanged<int> onPick;
  final VoidCallback onCustom;
  final ValueChanged<int> onStep;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final unit = ((w - 16) / 4).floorToDouble();
      double widthOf(int i) {
        if (editing) return i == _custom ? w : 0;
        return i == selected ? unit * 2 : unit;
      }

      double gapBefore(int i) => (editing || i == 0) ? 0 : 8;

      return SizedBox(
        height: 52,
        child: Row(
          children: [
            for (var i = 0; i < programs.length; i++)
              _box(
                width: widthOf(i),
                gap: gapBefore(i),
                selected: selected == i,
                dashed: false,
                visible: !editing,
                child: _ProgramLabel(
                  title: programs[i].name,
                  sub: formatDuration(programs[i].minutes),
                  bold: selected == i,
                  onTap: () => onPick(i),
                ),
              ),
            _box(
              width: widthOf(_custom),
              gap: gapBefore(2),
              selected: selected == _custom,
              dashed: selected != _custom,
              visible: true,
              child: LayoutBuilder(builder: (context, b) {
                if (editing && b.maxWidth > 220) {
                  return _CustomEditor(minutes: customMin, onStep: onStep, onDone: onDone);
                }
                return _ProgramLabel(
                  title: t.custom,
                  sub: selected == _custom ? formatDuration(customMin) : t.pickTime,
                  bold: selected == _custom,
                  onTap: onCustom,
                );
              }),
            ),
          ],
        ),
      );
    });
  }

  Widget _box({
    required double width,
    required double gap,
    required bool selected,
    required bool dashed,
    required bool visible,
    required Widget child,
  }) {
    final border = selected
        ? Border.all(color: C.ink, width: 1.5)
        : Border.all(color: dashed ? C.ink.withAlpha(115) : Colors.transparent, width: 1.5);
    return AnimatedContainer(
      duration: _anim,
      curve: easeOut,
      width: width,
      margin: EdgeInsets.only(left: gap),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: selected ? C.white : (dashed ? Colors.transparent : C.white.withAlpha(115)),
        borderRadius: BorderRadius.circular(18),
        border: border,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: visible ? 1 : 0,
        child: LayoutBuilder(
          builder: (context, b) => b.maxWidth < 44 ? const SizedBox.shrink() : child,
        ),
      ),
    );
  }
}

class _ProgramLabel extends StatelessWidget {
  const _ProgramLabel({required this.title, required this.sub, required this.bold, required this.onTap});

  final String title;
  final String sub;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      radius: 18,
      selected: bold,
      label: '$title, $sub',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: font(size: 14, weight: bold ? FontWeight.w600 : FontWeight.w500)),
            Text(sub, maxLines: 1, overflow: TextOverflow.clip, style: font(size: 12, color: C.sub)),
          ],
        ),
      ),
    );
  }
}

class _CustomEditor extends StatelessWidget {
  const _CustomEditor({required this.minutes, required this.onStep, required this.onDone});

  final int minutes;
  final ValueChanged<int> onStep;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          RoundIcon(icon: Icons.remove, label: t.minus15, onTap: () => onStep(-15),
              background: C.pink, foreground: C.ink, size: 40),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formatDuration(minutes), style: font(size: 18, weight: FontWeight.w600, features: tabular)),
                Text(t.customTime, style: font(size: 11, color: C.sub)),
              ],
            ),
          ),
          RoundIcon(icon: Icons.add, label: t.plus15, onTap: () => onStep(15),
              background: C.pink, foreground: C.ink, size: 40),
          const SizedBox(width: 6),
          RoundIcon(icon: Icons.check, label: t.applyTime, onTap: onDone, size: 40),
        ],
      ),
    );
  }
}
