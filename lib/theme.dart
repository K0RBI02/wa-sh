import 'package:flutter/material.dart';

import 'models.dart';

/// Farben der App. Hell und dunkel – umgeschaltet über [C.dark], das die App
/// aus der Systemeinstellung setzt. Die Doodles kehren sich dabei von selbst
/// um: Striche werden hell, Flächen dunkel.
class C {
  C._();

  static bool dark = false;

  static Color _pick(int light, int night) => Color(dark ? night : light);

  static Color get ink => _pick(0xFF212529, 0xFFE9ECEF);
  static Color get doodle => _pick(0xFF1A1A1A, 0xFFE9ECEF);
  static Color get bg => _pick(0xFFF5F6F7, 0xFF111315);
  static Color get white => _pick(0xFFFFFFFF, 0xFF1D2024);
  static Color get pink => _pick(0xFFF7D6D2, 0xFF4D3734);
  static Color get green => _pick(0xFFEEF6DC, 0xFF39422C);
  static Color get peach => _pick(0xFFFCE3CF, 0xFF4D3B2D);
  static Color get sub => _pick(0xFF3B4046, 0xFFC4C9CE);
  static Color get muted => _pick(0xFF5C6168, 0xFF9AA0A6);
  static Color get line => _pick(0xFFD6D9DC, 0xFF3A3F45);
  static Color get good => _pick(0xFF3E8E41, 0xFF6CC070);
  static Color get bad => _pick(0xFFC0392B, 0xFFEF7A6D);

  static Color machine(Machine m) => m == Machine.wash ? pink : peach;
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
TextStyle display([double size = 58]) =>
    font(size: size, weight: FontWeight.w600, height: 0.95, spacing: -0.035 * size);

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
