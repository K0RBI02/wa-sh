import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../theme.dart';

/// Wie sich ein Teil eines Doodles bewegt. Alles bewusst dezent.
enum DoodleAnim { none, bob, spin, tumble, ring, buzz, hum, nudge }

/// Ein Strich oder eine Fläche eines Doodles (Koordinaten im viewBox-System).
class DoodlePart {
  DoodlePart.path(
    String d, {
    this.fill,
    this.stroke = inkStroke,
    this.width = 4,
    this.anim = DoodleAnim.none,
    this.pivot,
    this.delay = 0,
  }) : _build = (() => parseSvgPathData(d));

  DoodlePart.circle(
    double cx,
    double cy,
    double r, {
    this.fill,
    this.stroke = inkStroke,
    this.width = 4,
    this.anim = DoodleAnim.none,
    this.pivot,
    this.delay = 0,
  }) : _build = (() => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

  DoodlePart.rect(
    double x,
    double y,
    double w,
    double h,
    double radius, {
    this.fill,
    this.stroke = inkStroke,
    this.width = 4,
    this.anim = DoodleAnim.none,
    this.pivot,
    this.delay = 0,
  }) : _build = (() => Path()..addRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(radius))));

  /// Weißer Punkt ohne Kontur (die kleinen Sprenkel in den schwarzen Flächen).
  factory DoodlePart.dot(double cx, double cy, double r) =>
      DoodlePart.circle(cx, cy, r, fill: Pal.day.white, stroke: null);

  final Path Function() _build;
  late final Path path = _build();
  final Color? fill;
  /// Platzhalter für „Strichfarbe der Doodles“ – wird erst beim Zeichnen
  /// aufgelöst, damit hell/dunkel wechseln kann.
  static const inkStroke = Color(0x01000000);

  final Color? stroke;
  final double width;
  final DoodleAnim anim;
  final Offset? pivot;

  /// Versatz in Sekunden, damit z. B. drei Striche nacheinander wippen.
  final double delay;
}

class DoodleDef {
  const DoodleDef(this.viewBox, this.parts);
  final Size viewBox;
  final List<DoodlePart> parts;
}

/// Zeichnet ein Doodle und spielt seine Animationen in Schleife ab.
/// Bei „Bewegung reduzieren“ bleibt alles stehen.
class Doodle extends StatefulWidget {
  const Doodle(this.def, {super.key, required this.width});

  final DoodleDef def;
  final double width;

  @override
  State<Doodle> createState() => _DoodleState();
}

/// Gemeinsame Schleifenlänge: alle Einzelperioden passen glatt hinein.
const double _loopSeconds = 9.6;

class _DoodleState extends State<Doodle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vb = widget.def.viewBox;
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.width,
        height: widget.width * vb.height / vb.width,
        child: CustomPaint(painter: _DoodlePainter(widget.def, _c)),
      ),
    );
  }
}

class _DoodlePainter extends CustomPainter {
  _DoodlePainter(this.def, this.t) : super(repaint: t);

  final DoodleDef def;
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / def.viewBox.width, size.height / def.viewBox.height);
    final secs = t.value * _loopSeconds;

    for (final p in def.parts) {
      final s = secs - p.delay;
      var opacity = 1.0;
      canvas.save();

      switch (p.anim) {
        case DoodleAnim.none:
          break;
        case DoodleAnim.bob:
          canvas.translate(0, -5 * _wave(s, 1.6));
        case DoodleAnim.nudge:
          final k = _wave(s, 1.6);
          canvas.translate(-3 * k, 2 * k);
        case DoodleAnim.spin:
          _rotate(canvas, p, 2 * math.pi * _phase(s, 3.2));
        case DoodleAnim.tumble:
          _rotate(canvas, p, _deg(-18 * math.cos(2 * math.pi * _phase(s, 2.4))));
        case DoodleAnim.ring:
          _rotate(canvas, p, _deg(_keyframes(_phase(s, 2.4), _ringFrames)));
        case DoodleAnim.buzz:
          opacity = _keyframes(_phase(s, 2.4), _buzzFrames);
        case DoodleAnim.hum:
          final k = _wave(s, 1.2);
          opacity = 0.3 + 0.7 * k;
          canvas.translate(-2 * k, 0);
      }

      if (p.fill != null) {
        canvas.drawPath(p.path, Paint()..color = _alpha(p.fill!, opacity));
      }
      // Doodles stehen immer auf Pastell → immer die dunkle Strichfarbe.
      final stroke = p.stroke == DoodlePart.inkStroke ? Pal.day.doodle : p.stroke;
      if (stroke != null) {
        canvas.drawPath(
          p.path,
          Paint()
            ..color = _alpha(stroke, opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = p.width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  void _rotate(Canvas canvas, DoodlePart p, double angle) {
    final c = p.pivot ?? p.path.getBounds().center;
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.translate(-c.dx, -c.dy);
  }

  static double _phase(double s, double period) {
    final x = (s / period) % 1.0;
    return x < 0 ? x + 1 : x;
  }

  /// 0 → 1 → 0, weich (wie ease-in-out hin und zurück).
  static double _wave(double s, double period) => 0.5 - 0.5 * math.cos(2 * math.pi * _phase(s, period));

  static double _deg(double d) => d * math.pi / 180;

  static Color _alpha(Color c, double o) => o >= 1 ? c : c.withAlpha((c.a * 255 * o).round().clamp(0, 255));

  static const _ringFrames = <List<double>>[
    [0, 0], [0.55, 0], [0.60, 14], [0.65, -12], [0.70, 10], [0.75, -8], [0.80, 5], [0.85, -3], [1.0, 0],
  ];
  static const _buzzFrames = <List<double>>[
    [0, 0.25], [0.55, 0.25], [0.60, 1], [0.85, 1], [0.90, 0.25], [1.0, 0.25],
  ];

  static double _keyframes(double x, List<List<double>> f) {
    for (var i = 1; i < f.length; i++) {
      if (x <= f[i][0]) {
        final a = f[i - 1], b = f[i];
        final span = b[0] - a[0];
        final k = span <= 0 ? 1.0 : (x - a[0]) / span;
        return a[1] + (b[1] - a[1]) * k;
      }
    }
    return f.last[1];
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.def != def;
}
