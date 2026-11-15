import 'package:flutter/material.dart';

import 'models.dart';

class C {
  static const ink = Color(0xFF212529);
  static const doodle = Color(0xFF1A1A1A);
  static const bg = Color(0xFFF5F6F7);
  static const white = Color(0xFFFFFFFF);
  static const pink = Color(0xFFF7D6D2);
  static const green = Color(0xFFEEF6DC);
  static const peach = Color(0xFFFCE3CF);
  static const sub = Color(0xFF3B4046);
  static const muted = Color(0xFF5C6168);
  static const line = Color(0xFFD6D9DC);

  static Color machine(Machine m) => m == Machine.wash ? pink : peach;
}

/// Instrument Sans liegt fest in der App (assets/fonts), kein Download nötig.
const fontFamily = 'InstrumentSans';

TextStyle font({
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color color = C.ink,
  double? height,
  double? spacing,
  List<FontFeature>? features,
}) =>
    TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
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
