import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../catalog/presentation/widgets/price_tags.dart';
import '../../domain/cart.dart';
import '../add_stepper.dart';
import '../cart_controller.dart';
import '../cart_texts.dart';
import '../quantity_dialog.dart';

/// One cart line (`03 §2.8`): image, name, pack size, the server's billed
/// price (`price_per_unit`; "₹87/box" with a "Wholesale rate" tag for items
/// with volume prices) and MRP, the minimum per order when above 1, the
/// quantity box (tap to
/// type a quantity, capped at `orderable_quantity`; 0 removes the line), the
/// line total and a remove button. A stock or minimum problem shows a flag and
/// its fix action.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({required this.line, super.key});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pending = ref.watch(
      cartProvider.select((c) => c.isPending(line.variantId)),
    );
    final cart = ref.read(cartProvider.notifier);
    final id = '${line.variantId}';
    Future<void> run(Future<void> Function() change) =>
        runCartChange(context, change, cart: ref.read(cartProvider).snapshot);

    final flagged = line.issue != null;
    final issueText = flagged ? lineIssueText(l10n, line) : null;
    final fixLabel = flagged ? lineFixText(l10n, line) : null;
    final outOfStock = flagged && line.orderableQuantity == 0;
    // The flag already says "Order at least N".
    final minHint =
        line.variant.hasMinQty &&
        line.issue?.code != CartIssueCode.minQtyRequired;

    return Padding(
      key: ValueKey('cart-line-$id'),
      padding: const EdgeInsets.symmetric(vertical: JivoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(JivoRadii.sm),
            child: SizedBox.square(
              dimension: 56,
              child: ProductImage(url: line.imageUrl),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: JivoSpacing.xs),
                if (line.variant.hasPriceTiers || line.priceTier != null)
                  _TierRate(line: line)
                else
                  PriceLine(price: line.billedPrice, mrp: line.mrp),
                if (minHint) MinQtyHint(variant: line.variant),
                if (issueText != null)
                  Text(
                    issueText,
                    key: ValueKey('cart-line-issue-$id'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (fixLabel != null)
                  TextButton(
                    key: ValueKey('cart-line-fix-$id'),
                    onPressed: pending
                        ? null
                        : () => run(() => cart.fixLine(line)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: JivoSpacing.sm,
                      ),
                    ),
                    child: Text(fixLabel),
                  ),
              ],
            ),
          ),
          const SizedBox(width: JivoSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!outOfStock)
                SizedBox(
                  width: 112,
                  child: DelayedPending(
                    pending: pending,
                    builder: (context, slow) => QuantityBox(
                      id: 'line-$id',
                      quantity: line.quantity,
                      busy: slow,
                      onTap: pending
                          ? null
                          : () async {
                              final typed = await showQuantityDialog(
                                context,
                                current: line.quantity,
                                max: line.orderableQuantity,
                                min: line.minQty,
                              );
                              if (typed == null || !context.mounted) return;
                              await run(
                                () => cart.setLineQuantity(line, typed),
                              );
                            },
                    ),
                  ),
                ),
              const SizedBox(height: JivoSpacing.xs),
              Text(
                formatRupees(line.lineTotal),
                key: ValueKey('cart-line-total-$id'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                key: ValueKey('cart-line-remove-$id'),
                tooltip: l10n.removeItem(line.productName),
                onPressed: pending
                    ? null
                    : () => run(() => cart.removeLine(line)),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A line with volume prices: the billed rate ("₹87/box", the server's
/// `price_per_unit`), the struck-out MRP when it differs, and a
/// "Wholesale rate" tag while a tier applies (`price_tier`).
class _TierRate extends StatelessWidget {
  const _TierRate({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.jivoColors;
    final id = '${line.variantId}';
    final rate = formatRupees(line.billedPrice);
    final mrp = formatRupees(line.mrp);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: JivoSpacing.xs,
      runSpacing: 2,
      children: [
        Text(
          l10n.pricePerBox(rate),
          key: ValueKey('cart-line-rate-$id'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (mrp != rate)
          Text(
            mrp,
            semanticsLabel: l10n.mrpSemantics(mrp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        if (line.priceTier != null)
          DecoratedBox(
            key: ValueKey('cart-line-tier-$id'),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(JivoRadii.sm / 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                l10n.wholesaleRateTag,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
