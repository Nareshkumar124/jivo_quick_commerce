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

/// One cart line (`03 §2.8`): image, name, pack size, the server's price
/// and MRP, a stepper capped at `orderable_quantity`, the line total and a
/// remove button. A stock problem shows a flag and its fix action.
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
        runCartChange(context, change);

    final issueText = switch (line.issue) {
      CartLineIssue.none => null,
      CartLineIssue.reduced => l10n.onlyAvailable(line.availableQuantity ?? 0),
      CartLineIssue.unavailable => l10n.outOfStock,
    };
    final fixLabel = switch (line.issue) {
      CartLineIssue.none => null,
      CartLineIssue.reduced => l10n.updateQuantityTo(
        line.availableQuantity ?? 0,
      ),
      CartLineIssue.unavailable => l10n.removeAction,
    };

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
                PriceLine(price: line.sellingPrice, mrp: line.mrp),
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
              if (line.issue != CartLineIssue.unavailable)
                SizedBox(
                  width: 112,
                  child: QuantityStepper(
                    id: 'line-$id',
                    quantity: line.quantity,
                    productName: line.productName,
                    onDecrement: pending
                        ? null
                        : () => run(
                            () => cart.setLineQuantity(line, line.quantity - 1),
                          ),
                    onIncrement: pending
                        ? null
                        : () => run(
                            () => cart.setLineQuantity(line, line.quantity + 1),
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
