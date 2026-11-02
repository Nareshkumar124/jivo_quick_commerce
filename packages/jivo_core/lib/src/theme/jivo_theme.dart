import 'package:flutter/material.dart';

/// Brand colour tokens.
///
/// TODO(D-06): placeholder values until Jivo Marketing supplies the brand kit.
/// Only change the values here; widgets read colours from the theme.
abstract final class JivoBrandColors {
  /// Seed for the Material 3 colour scheme (a wellness green placeholder).
  static const seed = Color(0xFF2E7D32);

  static const success = Color(0xFF1B5E20);
  static const onSuccess = Color(0xFFFFFFFF);
  static const warning = Color(0xFF8A5300);
  static const onWarning = Color(0xFFFFFFFF);
}

/// Spacing scale in logical pixels.
abstract final class JivoSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page gutter.
  static const double gutter = lg;
}

/// Corner radii in logical pixels.
abstract final class JivoRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

/// Minimum touch target (`03 §4`).
const double kJivoMinTouchTarget = 48;

/// Semantic colours that Material's [ColorScheme] does not cover.
@immutable
class JivoColors extends ThemeExtension<JivoColors> {
  const JivoColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  static const light = JivoColors(
    success: JivoBrandColors.success,
    onSuccess: JivoBrandColors.onSuccess,
    warning: JivoBrandColors.warning,
    onWarning: JivoBrandColors.onWarning,
  );

  static const dark = JivoColors(
    success: Color(0xFF81C784),
    onSuccess: Color(0xFF00390A),
    warning: Color(0xFFFFB95C),
    onWarning: Color(0xFF462A00),
  );

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  @override
  JivoColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
  }) => JivoColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
  );

  @override
  JivoColors lerp(JivoColors? other, double t) {
    if (other == null) return this;
    return JivoColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}

/// Builds the app themes from the brand tokens.
abstract final class JivoTheme {
  static ThemeData light() => build(Brightness.light);

  static ThemeData dark() => build(Brightness.dark);

  static ThemeData build(
    Brightness brightness, {
    Color seed = JivoBrandColors.seed,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    const minButtonSize = Size(64, kJivoMinTouchTarget);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(JivoRadii.md),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      extensions: [
        brightness == Brightness.light ? JivoColors.light : JivoColors.dark,
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minButtonSize,
          shape: buttonShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: minButtonSize,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minButtonSize,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minButtonSize),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(JivoRadii.md),
        ),
      ),
    );
  }
}

/// Shortcut for the [JivoColors] extension of the current theme.
extension JivoThemeContext on BuildContext {
  JivoColors get jivoColors =>
      Theme.of(this).extension<JivoColors>() ?? JivoColors.light;
}
