import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../catalog/domain/catalog_models.dart';
import 'cart_controller.dart';

/// ADD, which becomes − qty + once the variant is in the cart (`03 §2.5`).
///
/// Out-of-stock variants show "Out of stock" instead. Plus stops at the
/// server's `orderable_quantity` with a message. Buttons are disabled while
/// a change for this variant is in flight. Every target is 48 dp.
class AddStepper extends ConsumerWidget {
  const AddStepper({
    required this.variant,
    required this.productName,
    super.key,
  });

  final CatalogVariant variant;

  /// For screen-reader labels ("Add Jivo Canola Oil to cart").
  final String productName;

  Future<void> _run(BuildContext context, Future<void> Function() change) =>
      runCartChange(context, change);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cartAvailableProvider)) {
      return variant.inStock
          ? const CartComingSoonLabel()
          : const OutOfStockLabel();
    }
    final quantity = ref.watch(
      cartProvider.select((c) => c.quantityOf(variant.id)),
    );
    final pending = ref.watch(
      cartProvider.select((c) => c.isPending(variant.id)),
    );
    final cart = ref.read(cartProvider.notifier);
    final l10n = AppLocalizations.of(context);

    if (quantity == 0 && !variant.inStock) {
      return const OutOfStockLabel();
    }
    if (quantity == 0) {
      return AddButton(
        key: ValueKey('add-${variant.id}'),
        semanticsLabel: l10n.addToCartSemantics(productName),
        onPressed: pending
            ? null
            : () => _run(
                context,
                () => cart.increment(variant, productName: productName),
              ),
      );
    }
    return QuantityStepper(
      id: '${variant.id}',
      quantity: quantity,
      productName: productName,
      onDecrement: pending
          ? null
          : () => _run(context, () => cart.decrement(variant)),
      onIncrement: pending
          ? null
          : () => _run(
              context,
              () => cart.increment(variant, productName: productName),
            ),
    );
  }
}

/// Runs a cart change and shows the cap or server error as a message.
Future<void> runCartChange(
  BuildContext context,
  Future<void> Function() change,
) async {
  try {
    await change();
  } on CartLimitException catch (e) {
    if (context.mounted) {
      showMessage(context, AppLocalizations.of(context).maxQtyReached(e.max));
    }
  } catch (error) {
    if (context.mounted) {
      showMessage(context, describeErrorWithDetails(context, error));
    }
  }
}

/// Staging and prod before the Phase 3 cart: no ADD yet.
class CartComingSoonLabel extends StatelessWidget {
  const CartComingSoonLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: kJivoMinTouchTarget,
      child: Center(
        child: Text(
          AppLocalizations.of(context).cartComingSoonLabel,
          key: const Key('cart-coming-soon'),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class OutOfStockLabel extends StatelessWidget {
  const OutOfStockLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: kJivoMinTouchTarget,
      child: Center(
        child: Text(
          AppLocalizations.of(context).outOfStock,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The outlined full-width ADD button.
class AddButton extends StatelessWidget {
  const AddButton({
    required this.semanticsLabel,
    required this.onPressed,
    super.key,
  });

  final String semanticsLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary),
          padding: EdgeInsets.zero,
        ),
        child: Semantics(
          label: semanticsLabel,
          excludeSemantics: true,
          child: Text(
            AppLocalizations.of(context).addToCart,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// − qty +, 48 dp targets. Null callbacks disable both buttons.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.id,
    required this.quantity,
    required this.productName,
    required this.onDecrement,
    required this.onIncrement,
    super.key,
  });

  /// Key suffix: `dec-<id>`, `qty-<id>`, `inc-<id>`.
  final String id;
  final int quantity;
  final String productName;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    Widget button(String key, IconData icon, String label, VoidCallback? tap) =>
        IconButton(
          key: ValueKey('$key-$id'),
          tooltip: label,
          onPressed: tap,
          constraints: const BoxConstraints.tightFor(
            width: kJivoMinTouchTarget,
            height: kJivoMinTouchTarget,
          ),
          padding: EdgeInsets.zero,
          color: onPrimary,
          disabledColor: onPrimary.withValues(alpha: 0.6),
          icon: Icon(icon, size: 20),
        );

    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(JivoRadii.md),
      child: SizedBox(
        height: kJivoMinTouchTarget,
        child: Row(
          children: [
            button(
              'dec',
              Icons.remove,
              l10n.stepperDecrease(productName),
              onDecrement,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: l10n.stepperQuantity(quantity),
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$quantity',
                    key: ValueKey('qty-$id'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            button(
              'inc',
              Icons.add,
              l10n.stepperIncrease(productName),
              onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}
