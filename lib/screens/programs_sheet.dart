import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ha.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// „Meine Programme“ als Bottom Sheet – zwei Favoriten pro Maschine.
Future<void> showProgramsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: C.white,
    barrierColor: C.ink.withAlpha(115),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (_) => const _ProgramsSheet(),
  );
}

class _ProgramsSheet extends StatelessWidget {
  const _ProgramsSheet();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + insets),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Semantics(
                      header: true,
                      child: Text('Meine Programme', style: font(size: 28, weight: FontWeight.w600, height: 1.05, spacing: -0.5)),
                    ),
                    const SizedBox(height: 2),
                    Text('Zwei Favoriten pro Maschine', style: font(size: 14, color: C.muted)),
                  ]),
                ),
                RoundIcon(
                  icon: Icons.close,
                  label: 'Schließen',
                  onTap: () => Navigator.of(context).pop(),
                  background: C.bg,
                  foreground: C.ink,
                  size: 44,
                ),
              ],
            ),
            for (final m in Machine.values) ...[
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: C.machine(m),
                    shape: BoxShape.circle,
                    border: Border.all(color: C.ink, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Text(m.label, style: font(size: 18, weight: FontWeight.w600)),
              ]),
              const SizedBox(height: 10),
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _ProgramCard(
                  key: ValueKey('${m.name}-$i'),
                  machine: m,
                  index: i,
                  program: store.programs(m)[i],
                ),
              ],
            ],
            const SizedBox(height: 20),
            Text('Die Programme erscheinen beim Starten direkt zur Auswahl. Für alles andere gibt’s „Eigene Zeit“.',
                style: font(size: 14, height: 1.4, color: C.muted)),
            const SizedBox(height: 28),
            const _HomeAssistantCard(),
            const SizedBox(height: 20),
            PillButton(label: 'Speichern', expand: true, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _ProgramCard extends StatefulWidget {
  const _ProgramCard({super.key, required this.machine, required this.index, required this.program});

  final Machine machine;
  final int index;
  final Program program;

  @override
  State<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<_ProgramCard> {
  late final TextEditingController _name = TextEditingController(text: widget.program.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save(Program p) => StoreScope.read(context).updateProgram(widget.machine, widget.index, p);

  @override
  Widget build(BuildContext context) {
    final p = widget.program;
    final n = widget.index + 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _name,
              maxLength: 18,
              textInputAction: TextInputAction.done,
              style: font(size: 16, weight: FontWeight.w600),
              onChanged: (v) => _save(p.copyWith(name: v.trim().isEmpty ? 'Programm $n' : v.trim())),
              decoration: InputDecoration(
                labelText: 'Programm $n',
                labelStyle: font(size: 13, color: C.muted),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.only(top: 6, bottom: 6),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.line, width: 1.5)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.ink, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          RoundIcon(
            icon: Icons.remove,
            label: 'Programm $n: 5 Minuten weniger',
            onTap: () => _save(p.copyWith(minutes: (p.minutes - 5).clamp(10, 300))),
            background: C.machine(widget.machine),
            foreground: C.ink,
            size: 44,
          ),
          SizedBox(
            width: 68,
            child: Text(formatDuration(p.minutes),
                textAlign: TextAlign.center, style: font(size: 15, weight: FontWeight.w600, features: tabular)),
          ),
          RoundIcon(
            icon: Icons.add,
            label: 'Programm $n: 5 Minuten mehr',
            onTap: () => _save(p.copyWith(minutes: (p.minutes + 5).clamp(10, 300))),
            size: 44,
          ),
        ],
      ),
    );
  }
}

/// Home Assistant: Adresse + Kopplungscode aus der wa:sh-Integration.
class _HomeAssistantCard extends StatefulWidget {
  const _HomeAssistantCard();

  @override
  State<_HomeAssistantCard> createState() => _HomeAssistantCardState();
}

class _HomeAssistantCardState extends State<_HomeAssistantCard> {
  final _ha = HomeAssistant.instance;
  late final _url = TextEditingController(text: _ha.url);
  final _code = TextEditingController();
  bool _busy = false;
  bool _open = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action, String success) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _result = null;
    });
    final err = await action();
    if (!mounted) return;
    if (err == null) HapticFeedback.lightImpact();
    setState(() {
      _busy = false;
      _ok = err == null;
      _result = err ?? success;
      if (err == null) _code.clear();
    });
  }

  Future<void> _pair() => _run(() => _ha.pair(url: _url.text, code: _code.text), 'Gekoppelt');
  Future<void> _test() => _run(_ha.test, 'Erreichbar');
  Future<void> _unpair() async {
    await _ha.unpair();
    if (mounted) setState(() => _result = null);
  }

  InputDecoration _deco(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: font(size: 13, color: C.muted),
        hintStyle: font(size: 15, color: C.muted),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 6, bottom: 8),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.line, width: 1.5)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.ink, width: 1.5)),
      );

  Widget get _spinner => const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
      );

  /// Noch nicht gekoppelt: Adresse + Code.
  List<Widget> _pairForm() => [
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: font(size: 15, weight: FontWeight.w500),
          decoration: _deco('Adresse', 'http://homeassistant.local:8123'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          style: font(size: 15, weight: FontWeight.w500).copyWith(fontFeatures: tabular, letterSpacing: 1.5),
          decoration: _deco('Kopplungscode', 'z. B. K7Q-2M9'),
          onSubmitted: (_) => _pair(),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: _busy ? _spinner : PillButton(label: 'Koppeln', height: 46, onTap: _pair),
        ),
      ];

  /// Gekoppelt: Testen + Trennen.
  List<Widget> _pairedActions() => [
        const SizedBox(height: 4),
        Row(children: [
          _busy ? _spinner : PillButton(label: 'Verbindung testen', height: 46, onTap: _test),
          const Spacer(),
          TextButton(
            onPressed: _busy ? null : _unpair,
            style: TextButton.styleFrom(foregroundColor: C.ink, minimumSize: const Size(44, 44)),
            child: Text('Trennen', style: font(size: 15, weight: FontWeight.w600)),
          ),
        ]),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ha,
      builder: (context, _) {
        final status = _result ??
            (_ha.paired
                ? (_ha.lastError ?? 'Gekoppelt mit „${_ha.name}“')
                : 'Optional: In Home Assistant „Integration hinzufügen → wa:sh“ wählen, dann hier den Code eingeben.');
        final good = _result != null ? _ok : (_ha.paired && _ha.lastError == null);
        final dot = (_ha.paired || _result != null)
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: good ? const Color(0xFF3E8E41) : const Color(0xFFC0392B),
                  shape: BoxShape.circle,
                ),
              )
            : null;
        return Material(
          color: C.bg,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kopfzeile: Tippen klappt auf/zu.
              Semantics(
                button: true,
                expanded: _open,
                label: 'Home Assistant',
                child: InkWell(
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    child: ExcludeSemantics(
                      child: Row(children: [
                        const Icon(Icons.home_outlined, size: 22, color: C.ink),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Home Assistant', style: font(size: 18, weight: FontWeight.w600))),
                        if (dot != null && !_open) ...[dot, const SizedBox(width: 10)],
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(Icons.expand_more, color: C.ink),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: easeOut,
                alignment: Alignment.topCenter,
                child: !_open
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
              Row(children: [
                if (dot != null) ...[dot, const SizedBox(width: 6)],
                Expanded(child: Text(status, style: font(size: 13, color: C.muted))),
              ]),
              const SizedBox(height: 14),
              if (_ha.paired) ..._pairedActions() else ..._pairForm(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
