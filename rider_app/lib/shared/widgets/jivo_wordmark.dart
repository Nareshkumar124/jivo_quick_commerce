import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// The official Jivo face/wordmark (`assets/brand/jivo_wordmark.png`).
///
/// Drawn in its own dark green, or tinted with [color] (e.g. white on the
/// brand green). In dark mode it defaults to the theme's `onSurface`, since
/// dark green on a dark background can't be read. Screen readers hear
/// "Jivo Rider" (`appTitle`).
class JivoWordmark extends StatelessWidget {
  const JivoWordmark({super.key, this.height = 64, this.color});

  static const asset = 'assets/brand/jivo_wordmark.png';

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint =
        color ??
        (theme.brightness == Brightness.dark
            ? theme.colorScheme.onSurface
            : null);
    return Image.asset(
      asset,
      height: height,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
      semanticLabel: AppLocalizations.of(context).appTitle,
      filterQuality: FilterQuality.medium,
    );
  }
}
