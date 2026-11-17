import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';

/// The Indian veg / non-veg mark: a square with a dot (veg) or a triangle
/// (non-veg, FSSAI 2020).
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
        // Shape carries the meaning too (CA-12): veg is a dot, non-veg a
        // triangle pointing up, so it doesn't rest on colour alone.
        child: isVeg
            ? Container(
                key: const Key('veg-dot'),
                width: size / 2,
                height: size / 2,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            : CustomPaint(
                key: const Key('non-veg-triangle'),
                size: Size.square(size * 0.55),
                painter: _TrianglePainter(color),
              ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// The diet mark with its word next to it ("Veg" / "Non-veg"), for product
/// detail (CA-12). The word is the screen-reader label too.
class VegMarkWithLabel extends StatelessWidget {
  const VegMarkWithLabel({required this.isVeg, super.key});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VegMark(isVeg: isVeg, size: 18),
          const SizedBox(width: JivoSpacing.xs),
          ExcludeSemantics(
            child: Text(
              isVeg ? l10n.vegShort : l10n.nonVegShort,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
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
///
/// Each amount stays on one line and shrinks if it is wider than the space
/// (a narrow tile at a large text size): an amount broken over two lines
/// is hard to read and would push a tile past the height
/// `productTileExtent` reserves (price and MRP: at most one line each).
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
    final selling = displayRupees(price);
    final listed = displayRupees(mrp);
    final showMrp = listed != selling;
    Widget oneLine(Widget amount) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: amount,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: JivoSpacing.xs,
      children: [
        oneLine(
          Text(
            selling,
            semanticsLabel: l10n.priceSemantics(selling),
            style:
                (large
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (showMrp)
          oneLine(
            Text(
              listed,
              semanticsLabel: l10n.mrpSemantics(listed),
              style:
                  (large
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.lineThrough,
                      ),
            ),
          ),
      ],
    );
  }
}
