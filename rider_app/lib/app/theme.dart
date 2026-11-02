import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

/// Minimum height of rider primary actions (agent rule 9: at least 56 dp, for
/// use with gloves and on a bike). jivo_core's default is 48 dp.
const double kRiderPrimaryActionHeight = 56;

/// jivo_core's [JivoTheme] with the rider-specific button tweak: taller
/// buttons with a larger label, keeping the shared shape and colours.
ThemeData buildRiderTheme() {
  final base = JivoTheme.light();
  const minimumSize = WidgetStatePropertyAll(
    Size(64, kRiderPrimaryActionHeight),
  );
  const textStyle = WidgetStatePropertyAll(
    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  );
  ButtonStyle tweak(ButtonStyle? style) => (style ?? const ButtonStyle())
      .copyWith(minimumSize: minimumSize, textStyle: textStyle);
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: tweak(base.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: tweak(base.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: tweak(base.outlinedButtonTheme.style),
    ),
  );
}
