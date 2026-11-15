import 'package:flutter/material.dart';

import '../theme.dart';
import '../l10n.dart';

/// Die drei Linien oben (Schritt 1 / 2 / 3). Optional füllt sich das aktive
/// Segment als Ladebalken.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.active, this.progress});

  final int active;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Semantics(
      label: progress == null
          ? t.step(active + 1)
          : t.stepProgress(active + 1, (progress! * 100).round()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _segment(i, c)),
          ],
        ],
      ),
    );
  }

  Widget _segment(int i, Pal c) {
    if (i == active && progress != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 4,
          child: Stack(children: [
            Container(color: c.ink.withAlpha(46)),
            FractionallySizedBox(
              widthFactor: progress!.clamp(0.0, 1.0),
              child: Container(color: c.ink),
            ),
          ]),
        ),
      );
    }
    final done = i <= active;
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: done ? c.ink : c.ink.withAlpha(56),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Tippbare Fläche mit sauberer Semantik (statt Gesten auf Divs).
class Tap extends StatelessWidget {
  const Tap({super.key, required this.onTap, required this.child, this.label, this.selected, this.radius = 999});

  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final bool? selected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      ),
    );
  }
}

/// Der schwarze Pillen-Button aus der Vorlage.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap, this.icon, this.expand = false, this.height = 58});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Material(
      color: c.ink,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: font(size: 16, weight: FontWeight.w600, color: c.white)),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: c.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Zweizeiliger Nebenlink: „Doch nicht? / Zurück“.
class SideLink extends StatelessWidget {
  const SideLink({super.key, required this.question, required this.action, required this.onTap});

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Tap(
      onTap: onTap,
      radius: 12,
      label: '$question $action',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(question, style: font(size: 14, color: c.sub, height: 1.3)),
              Text(action, style: font(size: 14, weight: FontWeight.w600, height: 1.3, color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runder Icon-Button (48 px).
class RoundIcon extends StatelessWidget {
  const RoundIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.background,
    this.foreground,
    this.size = 48,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background ?? c.ink,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.45, color: foreground ?? c.white),
          ),
        ),
      ),
    );
  }
}

/// Fließtext mit **fetten** Schlüsselwörtern: Teile in ** ** werden fett.
class RichBody extends StatelessWidget {
  const RichBody(this.text, {super.key, this.size = 19});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = C.of(context);
    final parts = text.split('**');
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
            text: parts[i],
            style: font(size: size, height: 1.3, weight: i.isOdd ? FontWeight.w600 : FontWeight.w400, color: c.ink),
          ),
      ]),
    );
  }
}
