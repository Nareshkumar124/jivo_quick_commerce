import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';

/// The Indian veg / non-veg mark: a square with a dot.
class VegMark extends StatelessWidget {
  const VegMark({required this.isVeg, this.size = 16, super.key});

  final bool isVeg;
  final double size;

  static const _veg = Color(0xFF138808);
  static const _nonVeg = Color(0xFF8B4513);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = isVeg ? _veg : _nonVeg;
    return Semantics(
      label: isVeg ? l10n.vegMark : l10n.nonVegMark,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Container(
          width: size / 2,
          height: size / 2,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// "17% OFF", with the percentage from the server.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({required this.percent, super.key});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = context.jivoColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.success,
        borderRadius: BorderRadius.circular(JivoRadii.sm / 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          AppLocalizations.of(context).discountOff(percent),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: colors.onSuccess, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Selling price and, when different, the struck-out MRP. Both are server
/// decimal strings, only formatted here.
class PriceLine extends StatelessWidget {
  const PriceLine({
    required this.price,
    required this.mrp,
    this.large = false,
    super.key,
  });

  final String price;
  final String mrp;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selling = formatRupees(price);
    final listed = formatRupees(mrp);
    final showMrp = listed != selling;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: JivoSpacing.xs,
      children: [
        Text(
          selling,
          semanticsLabel: l10n.priceSemantics(selling),
          style:
              (large ? theme.textTheme.titleLarge : theme.textTheme.titleSmall)
                  ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (showMrp)
          Text(
            listed,
            semanticsLabel: l10n.mrpSemantics(listed),
            style:
                (large ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    ),
          ),
      ],
    );
  }
}
