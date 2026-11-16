import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jivo_core/jivo_core.dart';

/// Customer-only colours that Material's [ColorScheme] does not cover
/// (design `customer-theme-v2.md`). Read with `context.customerColors`.
@immutable
class CustomerColors extends ThemeExtension<CustomerColors> {
  const CustomerColors();

  Color get primaryDeep => const Color(0xFF075C36);
  Color get gold => const Color(0xFFFFC83D);
  Color get onGold => const Color(0xFF3B2600);
  Color get goldLight => const Color(0xFFFFE9A8);
  Color get goldEdge => const Color(0xFF9E6A00);
  Color get imageWell => const Color(0xFFF6EFE3);
  Color get shadow => const Color(0xFF0B3B22);

  List<Color> get headerGradient => const [Color(0xFF075C36), Color(0xFF0B7A47)];
  List<Color> get offerGradient => const [Color(0xFFFFE9A8), Color(0xFFFFC24D)];

  @override
  CustomerColors copyWith() => this;

  @override
  CustomerColors lerp(ThemeExtension<CustomerColors>? other, double t) => this;
}

extension CustomerColorsContext on BuildContext {
  CustomerColors get customerColors =>
      Theme.of(this).extension<CustomerColors>() ?? const CustomerColors();
}

/// The customer app theme: Jivo green, gold calls to action on an ivory
/// background. Built on `JivoTheme.light()`, which the rider app keeps.
/// The phone's own bars: a deep-green status bar with white icons (time,
/// battery) and a white navigation bar with dark icons, so both stay visible
/// on the ivory/white theme.
const customerSystemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0xFF075C36),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Color(0xFFFFFFFF),
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Color(0xFFE0E0E0),
);

/// Default for screens without an AppBar (login, OTP, onboarding, splash,
/// location, empty states): they have a light top, so the status icons are
/// dark. Home and AppBar screens set their own light-icon style over the
/// deep-green top. (Android 15 ignores statusBarColor: the app draws behind
/// the bar.)
const customerLightScreenStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Color(0xFFFFFFFF),
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Color(0xFFE0E0E0),
);

ThemeData buildCustomerTheme() {
  const c = CustomerColors();
  const green = Color(0xFF0B7A47);
  const ink = Color(0xFF181D17);
  const muted = Color(0xFF424840);
  const outline = Color(0xFF73796F);
  const edge = Color(0xFFE5DCCB);
  const white = Colors.white;
  final base = JivoTheme.light();
  final scheme = ColorScheme.fromSeed(seedColor: green).copyWith(
    primary: green,
    onPrimary: white,
    primaryContainer: const Color(0xFFD6F3E1),
    onPrimaryContainer: const Color(0xFF00391F),
    secondary: c.gold,
    onSecondary: c.onGold,
    secondaryContainer: c.goldLight,
    onSecondaryContainer: c.onGold,
    surface: const Color(0xFFFFF9F0),
    onSurface: ink,
    onSurfaceVariant: muted,
    surfaceContainerLowest: white,
    surfaceContainerLow: white,
    surfaceContainer: white,
    surfaceContainerHigh: const Color(0xFFF6EFE3),
    surfaceContainerHighest: const Color(0xFFECE5D8),
    outline: outline,
    outlineVariant: edge,
    inverseSurface: const Color(0xFF2D322B),
    onInverseSurface: const Color(0xFFEEF2E8),
    error: const Color(0xFFBA1A1A),
    onError: white,
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    shadow: c.shadow,
    surfaceTint: Colors.transparent,
  );

  TextStyle? t(TextStyle? s, double size, FontWeight w) =>
      s?.copyWith(fontSize: size, fontWeight: w);
  final tt = base.textTheme;
  final text = tt
      .copyWith(
        displaySmall: t(tt.displaySmall, 36, FontWeight.w800),
        headlineMedium: t(tt.headlineMedium, 28, FontWeight.w800),
        headlineSmall: t(tt.headlineSmall, 24, FontWeight.w800),
        titleLarge: t(tt.titleLarge, 22, FontWeight.w800),
        titleMedium: t(tt.titleMedium, 17, FontWeight.w700),
        titleSmall: t(tt.titleSmall, 15, FontWeight.w700),
        bodyLarge: t(tt.bodyLarge, 16, FontWeight.w400),
        bodyMedium: t(tt.bodyMedium, 14, FontWeight.w400),
        bodySmall: t(tt.bodySmall, 12, FontWeight.w400),
        labelLarge: t(tt.labelLarge, 15, FontWeight.w700),
        labelMedium: t(tt.labelMedium, 12, FontWeight.w700),
        labelSmall: t(tt.labelSmall, 11, FontWeight.w600),
      )
      .apply(bodyColor: ink, displayColor: ink);

  final goldButton = FilledButton.styleFrom(
    backgroundColor: c.gold,
    foregroundColor: c.onGold,
    minimumSize: const Size(64, 52),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(JivoRadii.md),
      side: BorderSide(color: c.goldEdge),
    ),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
  ).copyWith(
    side: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? BorderSide.none
          : BorderSide(color: c.goldEdge),
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.pressed)
          ? c.onGold.withValues(alpha: 0.12)
          : s.contains(WidgetState.hovered)
          ? c.onGold.withValues(alpha: 0.08)
          : null,
    ),
  );

  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(JivoRadii.md),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    extensions: [...base.extensions.values, c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.primaryDeep,
      foregroundColor: white,
      systemOverlayStyle: customerSystemUiStyle,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: white,
      ),
      iconTheme: const IconThemeData(color: white, size: 24),
      actionsIconTheme: const IconThemeData(color: white, size: 24),
    ),
    cardTheme: CardThemeData(
      color: white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: c.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JivoRadii.lg),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: goldButton),
    elevatedButtonTheme: ElevatedButtonThemeData(style: goldButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: green,
        side: const BorderSide(color: green, width: 1.5),
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JivoRadii.md),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: green,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: white,
      elevation: 3,
      shadowColor: c.shadow,
      surfaceTintColor: Colors.transparent,
      height: 68,
      indicatorColor: c.goldLight,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected) ? green : muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: green,
              )
            : const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border(outline, 1),
      border: border(outline, 1),
      focusedBorder: border(green, 2),
      errorBorder: border(scheme.error, 1),
      focusedErrorBorder: border(scheme.error, 2),
      hintStyle: const TextStyle(color: muted),
      floatingLabelStyle: const TextStyle(
        color: green,
        fontWeight: FontWeight.w600,
      ),
      prefixIconColor: muted,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF6EFE3),
      selectedColor: c.goldLight,
      side: const BorderSide(color: edge),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: c.onGold,
      ),
      checkmarkColor: c.onGold,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      iconTheme: const IconThemeData(size: 18),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: outline,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(JivoRadii.xl),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: edge, thickness: 1),
  );
}
