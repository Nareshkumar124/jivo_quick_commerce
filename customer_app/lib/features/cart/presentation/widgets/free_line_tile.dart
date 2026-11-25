import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../domain/cart.dart';
import '../cart_texts.dart';

/// The server's zero amount, shown as "₹0" on a free line.
const _free = '0.00';

/// A free carton in the cart (`free_lines`, ADR 0002): image, name, size,
/// "₹0" with the struck-out MRP, the quantity, a FREE tag and why it is
/// free ("Buy 10 get 1 free" / "Reward"). No stepper and no remove: the
/// server adds volume cartons by itself, and a reward's carton goes with
/// the reward (Remove on the coupon row). [every] is `free_offer.every`.
class FreeLineTile extends StatelessWidget {
  const FreeLineTile({required this.line, this.every, super.key});

  final FreeLine line;
  final int? every;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final id = '${line.variantId}-${line.source.name}';
    return Semantics(
      container: true,
      label: l10n.freeLineSemantics(
        line.productName,
        line.variantName,
        line.quantity,
        displayRupees(line.value),
      ),
      excludeSemantics: true,
      child: Padding(
        key: ValueKey('cart-free-line-$id'),
        padding: const EdgeInsets.symmetric(vertical: JivoSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(JivoRadii.md),
              child: SizedBox.square(
                dimension: 60,
                child: ColoredBox(
                  color: context.customerColors.imageWell,
                  child: ProductImage(url: line.imageUrl, onWell: true),
                ),
              ),
            ),
            const SizedBox(width: JivoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    line.variantName,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: JivoSpacing.xs),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: JivoSpacing.xs,
                    runSpacing: 2,
                    children: [
                      Text(
                        displayRupees(_free),
                        key: ValueKey('cart-free-line-price-$id'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        displayRupees(line.mrp),
                        key: ValueKey('cart-free-line-mrp-$id'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        '· ${l10n.freeLineQuantity(line.quantity)}',
                        key: ValueKey('cart-free-line-qty-$id'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: JivoSpacing.xs),
                  FreeSourceLabel(line: line, every: every),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The FREE tag and why the carton is free.
class FreeSourceLabel extends StatelessWidget {
  const FreeSourceLabel({required this.line, this.every, super.key});

  final FreeLine line;
  final int? every;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: JivoSpacing.xs,
      runSpacing: 2,
      children: [
        const FreeTag(),
        Text(
          freeLineSourceText(l10n, line.source, every: every),
          style: theme.textTheme.labelMedium?.copyWith(
            color: context.jivoColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The green "FREE" tag.
class FreeTag extends StatelessWidget {
  const FreeTag({super.key});

  @override
  Widget build(BuildContext context) {
    final success = context.jivoColors.success;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(JivoRadii.sm / 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          AppLocalizations.of(context).freeTag,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: success, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// A free carton in a compact list (checkout, order detail): name, size and
/// quantity, the FREE tag with its source, and "₹0" over the struck-out
/// value on the right. On an order, cartons the store couldn't supply are
/// named (dropped at ₹0, nothing to refund).
class FreeLineRow extends StatelessWidget {
  const FreeLineRow({required this.line, this.every, super.key});

  final FreeLine line;
  final int? every;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final id = '${line.variantId}-${line.source.name}';
    return Semantics(
      container: true,
      label: l10n.freeLineSemantics(
        line.productName,
        line.variantName,
        line.quantity,
        displayRupees(line.value),
      ),
      excludeSemantics: true,
      child: Padding(
        key: ValueKey('free-line-$id'),
        padding: const EdgeInsets.only(bottom: JivoSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 48,
              child: ProductImage(url: line.imageUrl),
            ),
            const SizedBox(width: JivoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.productName, style: theme.textTheme.bodyMedium),
                  Text(
                    '${line.variantName} · '
                    '${l10n.freeLineQuantity(line.quantity)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  FreeSourceLabel(line: line, every: every),
                  if (line.quantityUnavailable > 0)
                    Text(
                      l10n.freeLineUnavailable(line.quantityUnavailable),
                      key: ValueKey('free-line-unavailable-$id'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: JivoSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayRupees(_free),
                  key: ValueKey('free-line-total-$id'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  displayRupees(line.value),
                  key: ValueKey('free-line-value-$id'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
