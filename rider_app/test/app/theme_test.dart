import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/brand.dart';
import 'package:rider_app/app/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final theme = buildRiderTheme();
  final s = theme.colorScheme;

  test('primary is the logo green', () {
    expect(s.primary, kJivoBrandGreen);
  });

  test('primary text pairs pass AA (4.5:1)', () {
    expect(_contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
    expect(
      _contrast(s.onPrimaryContainer, s.primaryContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(_contrast(s.primary, s.surface), greaterThanOrEqualTo(4.5));
    expect(_contrast(s.onError, s.error), greaterThanOrEqualTo(4.5));
  });

  test('success, warning and online colours are unchanged', () {
    final jivo = theme.extension<JivoColors>()!;
    expect(jivo.success, JivoBrandColors.success);
    expect(jivo.warning, JivoBrandColors.warning);
    expect(
      theme.extension<RiderColors>()!.onlineBg,
      RiderColors.light.onlineBg,
    );
  });
}
