import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wash/theme.dart';

void main() {
  tearDown(() => C.dark = false);

  test('Dunkelmodus kehrt Schrift und Flächen um', () {
    C.dark = false;
    final inkLight = C.ink, surfaceLight = C.white;
    C.dark = true;
    expect(C.ink, isNot(inkLight));
    expect(C.white, isNot(surfaceLight));
    // Hell auf dunkel: Schrift heller als Fläche
    expect(C.ink.computeLuminance(), greaterThan(C.white.computeLuminance()));
    expect(buildTheme().brightness, Brightness.dark);
  });

  test('Hellmodus: dunkle Schrift auf hellem Grund', () {
    C.dark = false;
    expect(C.ink.computeLuminance(), lessThan(C.white.computeLuminance()));
    expect(buildTheme().brightness, Brightness.light);
  });
}
