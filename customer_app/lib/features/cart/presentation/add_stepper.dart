import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';
import 'cart_texts.dart';

/// ADD, which becomes − qty + once the variant is in the cart (`03 §2.5`).
///
/// Out-of-stock variants show "Out of stock" instead. ADD adds the
/// variant's `min_qty_per_order` at once; minus at that quantity removes
/// it. Plus stops at the server's `orderable_quantity` with a message.
/// Buttons are disabled while a change for this variant is in flight.
/// Every target is 48 dp.
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
      runCartChange(
        context,
        change,
        names: {variant.id: '$productName ${variant.name}'},
      );

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
    return DelayedPending(
      pending: pending,
      builder: (context, slow) => quantity == 0
          ? AddButton(
              key: ValueKey('add-${variant.id}'),
              semanticsLabel: l10n.addToCartSemantics(productName),
              busy: slow,
              onPressed: pending
                  ? null
                  : () => _run(
                      context,
                      () => cart.increment(variant, productName: productName),
                    ),
            )
          : QuantityStepper(
              id: '${variant.id}',
              quantity: quantity,
              productName: productName,
              busy: slow,
              onDecrement: pending
                  ? null
                  : () => _run(context, () => cart.decrement(variant)),
              onIncrement: pending
                  ? null
                  : () => _run(
                      context,
                      () => cart.increment(variant, productName: productName),
                    ),
            ),
    );
  }
}

/// How long a cart change may run before the stepper shows a spinner
/// (CA-17, `customer.motion.pendingSpinnerDelay`).
const kPendingSpinnerDelay = Duration(milliseconds: 300);

/// Builds with `slow: true` once [pending] has lasted [kPendingSpinnerDelay]
/// (CA-17): on slow data the stepper shows progress instead of only dimming,
/// and a fast answer never flashes a spinner.
class DelayedPending extends StatefulWidget {
  const DelayedPending({
    required this.pending,
    required this.builder,
    super.key,
  });

  final bool pending;
  final Widget Function(BuildContext context, bool slow) builder;

  @override
  State<DelayedPending> createState() => _DelayedPendingState();
}

class _DelayedPendingState extends State<DelayedPending> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(DelayedPending oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pending != widget.pending) _sync();
  }

  void _sync() {
    _timer?.cancel();
    _timer = null;
    if (widget.pending) {
      _timer = Timer(kPendingSpinnerDelay, () {
        if (mounted) setState(() => _slow = true);
      });
    } else {
      _slow = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.pending && _slow);
}

/// Runs a cart change and shows the cap or server error as a message, with
/// the server's details (e.g. how many can be ordered now).
Future<void> runCartChange(
  BuildContext context,
  Future<void> Function() change, {
  CartSnapshot? cart,
  Map<int, String> names = const {},
}) async {
  try {
    await change();
  } on CartLimitException catch (e) {
    if (context.mounted) {
      showMessage(context, AppLocalizations.of(context).maxQtyReached(e.max));
    }
  } catch (error) {
    if (context.mounted) {
      showMessage(
        context,
        cartErrorText(context, error, cart: cart, names: names),
      );
    }
  }
}

/// The minimum per order near ADD: "Min 5" ([compact], product tiles) or
/// "Minimum 5 per order" (product detail, variant picker, cart lines).
/// Nothing when the variant's `min_qty_per_order` is 1.
class MinQtyHint extends StatelessWidget {
  const MinQtyHint({required this.variant, this.compact = false, super.key});

  final CatalogVariant variant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!variant.hasMinQty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = variant.minQty;
    final style = compact
        ? theme.textTheme.labelSmall
        : theme.textTheme.bodySmall;
    return Semantics(
      // "Min 5" alone is unclear to a screen-reader user.
      label: l10n.minQtyPerOrder(count),
      excludeSemantics: true,
      child: Text(
        compact ? l10n.minQtyShort(count) : l10n.minQtyPerOrder(count),
        key: ValueKey('min-qty-${variant.id}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Staging and prod until the cart is enabled there (S3-B): no ADD yet.
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
    this.busy = false,
    super.key,
  });

  final String semanticsLabel;
  final VoidCallback? onPressed;

  /// A slow change is running: a 16 dp spinner instead of "ADD" (CA-17).
  final bool busy;

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
        child: busy
            ? Semantics(
                liveRegion: true,
                label: AppLocalizations.of(context).updatingQuantity,
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )
            : Semantics(
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
    this.busy = false,
    super.key,
  });

  /// Key suffix: `dec-<id>`, `qty-<id>`, `inc-<id>`.
  final String id;

  /// A slow change is running: a 16 dp spinner instead of the number,
  /// which changes only when the server answers (CA-17).
  final bool busy;
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
                label: busy
                    ? l10n.updatingQuantity
                    : l10n.stepperQuantity(quantity),
                excludeSemantics: true,
                child: busy
                    ? Center(
                        key: ValueKey('qty-busy-$id'),
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: onPrimary,
                          ),
                        ),
                      )
                    : FittedBox(
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
