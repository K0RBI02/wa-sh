import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';

/// Ein Farbsatz – hell oder dunkel.
class Pal {
  const Pal._({
    required this.ink,
    required this.doodle,
    required this.bg,
    required this.white,
    required this.sub,
    required this.muted,
    required this.line,
    required this.good,
    required this.bad,
  });

  final Color ink, doodle, bg, white, sub, muted, line, good, bad;

  // Die Pastelltöne bleiben auch im Dunkelmodus hell – Karten und Schritt-
  // Screens sind „helle Inseln“ (siehe [Pastel]).
  Color get pink => const Color(0xFFF7D6D2);
  Color get green => const Color(0xFFEEF6DC);
  Color get peach => const Color(0xFFFCE3CF);
  Color machine(Machine m) => m == Machine.wash ? pink : peach;

  static const day = Pal._(
    ink: Color(0xFF212529),
    doodle: Color(0xFF1A1A1A),
    bg: Color(0xFFF5F6F7),
    white: Color(0xFFFFFFFF),
    sub: Color(0xFF3B4046),
    muted: Color(0xFF5C6168),
    line: Color(0xFFD6D9DC),
    good: Color(0xFF3E8E41),
    bad: Color(0xFFC0392B),
  );

  static const night = Pal._(
    ink: Color(0xFFECEEF0),
    doodle: Color(0xFFECEEF0),
    bg: Color(0xFF121416),
    white: Color(0xFF1E2125),
    sub: Color(0xFFC4C9CE),
    muted: Color(0xFFA9AFB5),
    line: Color(0xFF3A3F45),
    good: Color(0xFF6CC070),
    bad: Color(0xFFEF7A6D),
  );
}

/// Farben der App. Hell und dunkel – umgeschaltet über [C.dark], das die App
/// aus der Systemeinstellung setzt. Auf Pastellflächen gilt immer der helle
/// Satz: dort [C.of] statt der statischen Getter verwenden.
class C {
  C._();

  static bool dark = false;

  /// Farbsatz für dunkle/helle Grundflächen (folgt dem System).
  static Pal get current => dark ? Pal.night : Pal.day;

  /// Farbsatz an dieser Stelle im Baum – innerhalb von [Pastel] immer hell.
  static Pal of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Pastel>() != null ? Pal.day : current;

  static Color get ink => current.ink;
  static Color get doodle => current.doodle;
  static Color get bg => current.bg;
  static Color get white => current.white;
  static Color get pink => current.pink;
  static Color get green => current.green;
  static Color get peach => current.peach;
  static Color get sub => current.sub;
  static Color get muted => current.muted;
  static Color get line => current.line;
  static Color get good => current.good;
  static Color get bad => current.bad;

  static Color machine(Machine m) => current.machine(m);
}

/// Ganzer Screen als Pastell-Insel: helle Farben und dunkle Statusleisten-Symbole.
Widget pastelScreen(Widget child) => Pastel(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
        child: child,
      ),
    );

/// Helle Insel: Pastellkarten und -screens behalten im Dunkelmodus ihre hellen
/// Farben und dunkle Schrift. Setzt auch dunkle Statusleisten-Symbole.
class Pastel extends InheritedWidget {
  const Pastel({super.key, required super.child});

  @override
  bool updateShouldNotify(Pastel oldWidget) => false;
}

/// Instrument Sans liegt fest in der App (assets/fonts), kein Download nötig.
const fontFamily = 'InstrumentSans';

TextStyle font({
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  double? spacing,
  List<FontFeature>? features,
}) =>
    TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color ?? C.ink,
      height: height,
      letterSpacing: spacing,
      fontFeatures: features,
    );

/// Große zweizeilige Überschrift im Stil der Vorlage („Risk / Brave“).
TextStyle display([double size = 58, Color? color]) =>
    font(size: size, weight: FontWeight.w600, height: 0.95, spacing: -0.035 * size, color: color);

const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: C.dark ? Brightness.dark : Brightness.light,
    colorSchemeSeed: C.ink,
    scaffoldBackgroundColor: C.bg,
    fontFamily: fontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink),
  );
}

/// Sanfte Standard-Kurve für Breiten- und Farbwechsel.
const easeOut = Cubic(0.2, 0.8, 0.2, 1);
