import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// The official Jivo wordmark (face and "JIVO", dark green, 2026-11-23).
/// Screen readers hear "Jivo". Pass [color] to tint it, e.g. white on a
/// green or dark background.
class JivoWordmark extends StatelessWidget {
  const JivoWordmark({this.height = 48, this.color, super.key});

  static const asset = 'assets/brand/jivo_wordmark.png';

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).brandName,
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          asset,
          height: height,
          color: color,
          colorBlendMode: color == null ? null : BlendMode.srcIn,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          // Tests and a missing asset still show the brand name.
          errorBuilder: (context, _, _) => SizedBox(
            height: height,
            child: Center(child: Text(AppLocalizations.of(context).brandName)),
          ),
        ),
      ),
    );
  }
}
