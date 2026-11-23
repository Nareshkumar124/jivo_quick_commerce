import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../catalog/presentation/widgets/price_tags.dart';
import '../../../home/presentation/home_product_card.dart' show QuantityStepper;
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
/// its fix action. A store price that changed since the customer last set
/// the quantity shows "Price changed: was ₹X, now ₹Y" (CA-19); it clears on
/// the next quantity change, so it needs no extra tap.
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

    /// Removes the line (the delete button, or − at the minimum per
    /// order: the same server change) and offers Undo.
    Future<void> remove({bool viaMinus = false}) async {
      // The tile goes away with the line: build the notice first.
      final notice = CartRemovedNotice.of(context);
      var removed = false;
      await run(() async {
        if (viaMinus) {
          await cart.setLineQuantity(line, line.quantity - 1);
        } else {
          await cart.removeLine(line);
        }
        removed = true;
      });
      if (!removed) return;
      notice.show(
        name: '${line.productName} ${line.variantName}',
        variantId: line.variantId,
        undoKey: ValueKey('cart-line-undo-$id'),
        // An out-of-stock line can't come back; nothing to undo. Undo is
        // the same server call as ADD: the server still checks stock and
        // price.
        restore: outOfStock
            ? null
            : () => cart.setVariantQuantity(
                line.variant,
                line.quantity,
                productName: line.productName,
              ),
      );
    }

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(JivoRadii.md),
      child: SizedBox.square(
        dimension: 60,
        child: ColoredBox(
          color: context.customerColors.imageWell,
          child: ProductImage(url: line.imageUrl, onWell: true),
        ),
      ),
    );
    final info = <Widget>[
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
      if (line.priceChanged) CartLinePriceChange(line: line),
      if (minHint) MinQtyHint(variant: line.variant),
    ];
    final issue = <Widget>[
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
          onPressed: pending ? null : () => run(() => cart.fixLine(line)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.sm),
          ),
          child: Text(fixLabel),
        ),
    ];
    final stepper = outOfStock
        ? null
        : SizedBox(
            width: 132,
            child: DelayedPending(
              pending: pending,
              // − qty + (home redesign): the same setLineQuantity call as
              // the typed quantity, one step at a time.
              builder: (context, slow) => QuantityStepper(
                id: 'line-$id',
                name: line.productName,
                quantity: line.quantity,
                busy: slow,
                // − at the minimum per order removes the line: say so,
                // with Undo.
                onMinus: pending
                    ? null
                    : line.quantity - 1 < line.minQty
                    ? () => remove(viaMinus: true)
                    : () => run(
                        () => cart.setLineQuantity(line, line.quantity - 1),
                      ),
                onPlus: pending
                    ? null
                    : () => run(
                        () => cart.setLineQuantity(line, line.quantity + 1),
                      ),
                onType: pending
                    ? null
                    : () async {
                        final typed = await showQuantityDialog(
                          context,
                          current: line.quantity,
                          max: line.orderableQuantity,
                          min: line.minQty,
                        );
                        if (typed == null || !context.mounted) return;
                        await run(() => cart.setLineQuantity(line, typed));
                      },
              ),
            ),
          );
    final total = Text(
      displayRupees(line.lineTotal),
      key: ValueKey('cart-line-total-$id'),
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
    final removeButton = IconButton(
      key: ValueKey('cart-line-remove-$id'),
      tooltip: l10n.removeItem(line.productName),
      onPressed: pending ? null : () => remove(),
      icon: const Icon(Icons.delete_outline),
    );

    // From 1.3x text the trailing column would squeeze the name to a few
    // characters: stack the line instead (CA-18). Image and details, then
    // the stepper with the total and remove, then the issue and its fix.
    final stacked = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.3;
    if (stacked) {
      return Padding(
        key: ValueKey('cart-line-$id'),
        padding: const EdgeInsets.symmetric(vertical: JivoSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                image,
                const SizedBox(width: JivoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: JivoSpacing.sm),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: JivoSpacing.sm,
              runSpacing: JivoSpacing.xs,
              children: [
                ?stepper,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [total, removeButton],
                ),
              ],
            ),
            ...issue.map(
              (w) =>
                  Align(alignment: AlignmentDirectional.centerStart, child: w),
            ),
          ],
        ),
      );
    }

    return Padding(
      key: ValueKey('cart-line-$id'),
      padding: const EdgeInsets.symmetric(vertical: JivoSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image,
          const SizedBox(width: JivoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [...info, ...issue],
            ),
          ),
          const SizedBox(width: JivoSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ?stepper,
              const SizedBox(height: JivoSpacing.xs),
              total,
              removeButton,
            ],
          ),
        ],
      ),
    );
  }
}

/// "Price changed: was ₹129, now ₹119" under a line whose store price
/// changed since the customer last set its quantity (CA-19). Both prices are
/// the server's strings (`previous_selling_price` and today's
/// `selling_price`); nothing is computed. An icon, not only colour, marks
/// it, and the text wraps at large text sizes.
class CartLinePriceChange extends StatelessWidget {
  const CartLinePriceChange({required this.line, super.key});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: JivoSpacing.xs),
      child: MergeSemantics(
        child: Row(
          key: ValueKey('cart-line-price-changed-${line.variantId}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: context.jivoColors.warning,
              ),
            ),
            const SizedBox(width: JivoSpacing.xs),
            Flexible(
              child: Text(
                l10n.cartLinePriceChanged(
                  displayRupees(line.previousSellingPrice),
                  displayRupees(line.sellingPrice),
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
    final rate = displayRupees(line.billedPrice);
    final mrp = displayRupees(line.mrp);
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
