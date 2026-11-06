import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

/// Rider sizes from `design/tokens/rider.tokens.json` (`rider.size.*`, dp).
/// Minimum height of rider primary actions (agent rule 9: at least 56 dp).
const double kRiderPrimaryActionHeight = 56;

/// `rider.size.onlineControl`: home's bottom-pinned online control.
const double kRiderOnlineControlHeight = 72;

/// `rider.size.offerAccept`.
const double kRiderAcceptHeight = 64;

/// `rider.size.listRowMin`: permissions gate rows, home records rows.
const double kRiderListRowMin = 64;

/// Rider high-contrast (sunlight) colours, built from
/// `design/tokens/rider.tokens.json` (UX audit RD-05). Every text pair is
/// 7:1 or more except [danger], which is always paired with an icon and
/// words. Brand hues are placeholders: TODO(D-06).
///
/// Read with `RiderColors.of(context)`.
@immutable
class RiderColors extends ThemeExtension<RiderColors> {
  const RiderColors({
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.onlineBg,
    required this.onlineFg,
    required this.codBg,
    required this.codBorder,
    required this.codText,
    required this.danger,
    required this.onDanger,
    required this.neutralContainer,
  });

  /// The values of `rider.tokens.json`.
  static const light = RiderColors(
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1C19),
    textSecondary: Color(0xFF44483E),
    onlineBg: Color(0xFF1B5E20),
    onlineFg: Color(0xFFFFFFFF),
    codBg: Color(0xFFFFF4D6),
    codBorder: Color(0xFF8A5300),
    codText: Color(0xFF1A1C19),
    danger: Color(0xFFBA1A1A),
    onDanger: Color(0xFFFFFFFF),
    neutralContainer: Color(0xFFECEFE7),
  );

  /// `rider.border.*` width.
  static const borderWidth = 2.0;

  static RiderColors of(BuildContext context) =>
      Theme.of(context).extension<RiderColors>() ?? light;

  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color onlineBg;
  final Color onlineFg;
  final Color codBg;
  final Color codBorder;
  final Color codText;
  final Color danger;
  final Color onDanger;
  final Color neutralContainer;

  /// `rider.border.codContainer` on `rider.color.cod.bg`.
  BoxDecoration codDecoration({double radius = 12}) => BoxDecoration(
    color: codBg,
    border: Border.all(color: codBorder, width: borderWidth),
    borderRadius: BorderRadius.circular(radius),
  );

  @override
  RiderColors copyWith({
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? onlineBg,
    Color? onlineFg,
    Color? codBg,
    Color? codBorder,
    Color? codText,
    Color? danger,
    Color? onDanger,
    Color? neutralContainer,
  }) => RiderColors(
    surface: surface ?? this.surface,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    onlineBg: onlineBg ?? this.onlineBg,
    onlineFg: onlineFg ?? this.onlineFg,
    codBg: codBg ?? this.codBg,
    codBorder: codBorder ?? this.codBorder,
    codText: codText ?? this.codText,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    neutralContainer: neutralContainer ?? this.neutralContainer,
  );

  @override
  RiderColors lerp(RiderColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return RiderColors(
      surface: c(surface, other.surface),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      onlineBg: c(onlineBg, other.onlineBg),
      onlineFg: c(onlineFg, other.onlineFg),
      codBg: c(codBg, other.codBg),
      codBorder: c(codBorder, other.codBorder),
      codText: c(codText, other.codText),
      danger: c(danger, other.danger),
      onDanger: c(onDanger, other.onDanger),
      neutralContainer: c(neutralContainer, other.neutralContainer),
    );
  }
}

/// The COD container (`rider.color.cod.*`, 2 dp border).
BoxDecoration riderCodDecoration(BuildContext context) =>
    RiderColors.of(context).codDecoration();

/// jivo_core's [JivoTheme] with the rider tweaks: taller buttons with a
/// larger label, high-contrast text, 2 dp outlines and no 12 sp text
/// (RD-05), plus the [RiderColors] extension.
ThemeData buildRiderTheme() {
  const rider = RiderColors.light;
  final base = JivoTheme.light();
  const minimumSize = WidgetStatePropertyAll(
    Size(64, kRiderPrimaryActionHeight),
  );
  const textStyle = WidgetStatePropertyAll(
    TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  );
  ButtonStyle tweak(ButtonStyle? style) => (style ?? const ButtonStyle())
      .copyWith(minimumSize: minimumSize, textStyle: textStyle);

  final scheme = base.colorScheme.copyWith(
    onSurface: rider.textPrimary,
    onSurfaceVariant: rider.textSecondary,
    outline: rider.textSecondary,
    error: rider.danger,
    onError: rider.onDanger,
  );
  final text = base.textTheme
      .copyWith(
        bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 14),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18),
        labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: 14),
        labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 14),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(bodyColor: rider.textPrimary, displayColor: rider.textPrimary);

  final outlined = tweak(base.outlinedButtonTheme.style).copyWith(
    foregroundColor: WidgetStatePropertyAll(rider.textPrimary),
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? rider.textSecondary.withValues(alpha: 0.4)
            : rider.textPrimary,
        width: RiderColors.borderWidth,
      ),
    ),
  );

  return base.copyWith(
    colorScheme: scheme,
    textTheme: text,
    extensions: [...base.extensions.values, rider],
    filledButtonTheme: FilledButtonThemeData(
      style: tweak(base.filledButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: tweak(base.elevatedButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlined),
  );
}
