import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';
import 'cart_texts.dart';
import 'quantity_dialog.dart';

/// ADD, which becomes a quantity box once the variant is in the cart
/// (`03 §2.5`). There is no − or +: both open the "Enter quantity" dialog
/// (bulk orders are typed), ADD prefilled with the variant's
/// `min_qty_per_order`, the box with the quantity in the cart. The dialog
/// checks the cap (`orderable_quantity`) and the minimum; one request sets
/// the quantity. Out-of-stock variants show "Out of stock" instead. Taps
/// are ignored while a change for this variant is in flight. Every target
/// is 48 dp.
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

  /// ADD or the quantity box: type a quantity, sent in one request.
  Future<void> _typeQuantity(
    BuildContext context,
    CartController cart,
    int quantity,
  ) async {
    final typed = await showQuantityDialog(
      context,
      current: quantity,
      initial: quantity == 0 ? variant.minQty : quantity,
      max: variant.maxSelectable,
      min: variant.minQty,
    );
    if (typed == null || !context.mounted) return;
    await _run(
      context,
      () => cart.setVariantQuantity(variant, typed, productName: productName),
    );
  }

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
              onPressed: pending ? null : () => _typeQuantity(context, cart, 0),
            )
          : QuantityBox(
              id: '${variant.id}',
              quantity: quantity,
              busy: slow,
              onTap: pending
                  ? null
                  : () => _typeQuantity(context, cart, quantity),
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

/// The full-width "Out of stock" pill where ADD would be (CA-11): text and
/// an icon at full contrast, the same 48 dp height, so the layout doesn't
/// jump.
class OutOfStockLabel extends StatelessWidget {
  const OutOfStockLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('out-of-stock-pill'),
      height: kJivoMinTouchTarget,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(JivoRadii.pill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.remove_shopping_cart_outlined,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: JivoSpacing.xs),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppLocalizations.of(context).outOfStock,
                maxLines: 1,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-width ADD button: green label on pale mint (home redesign).
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
      child: FilledButton(
        onPressed: onPressed,
        // Home redesign: green on pale mint with a thin green edge (was
        // gold), the same everywhere ADD appears.
        style: FilledButton.styleFrom(
          backgroundColor: context.customerColors.softTint,
          foregroundColor: theme.colorScheme.primary,
          disabledBackgroundColor: context.customerColors.softTint,
          disabledForegroundColor: theme.colorScheme.primary,
          side: BorderSide(color: theme.colorScheme.primary),
          minimumSize: const Size(64, kJivoMinTouchTarget),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(JivoRadii.md),
          ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 20),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context).addToCart,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The quantity in the cart as one tappable box, "100 ✎" (`03 §2.5`):
/// tapping it opens the "Enter quantity" dialog. Full width of its slot,
/// 48 dp tall, in the old stepper's colours. A null [onTap] ignores taps
/// (a change is in flight).
class QuantityBox extends StatelessWidget {
  const QuantityBox({
    required this.id,
    required this.quantity,
    required this.onTap,
    this.busy = false,
    super.key,
  });

  /// Key suffix: `qty-edit-<id>` (the tap target), `qty-<id>` (the number),
  /// `qty-busy-<id>` (the spinner).
  final String id;
  final int quantity;
  final VoidCallback? onTap;

  /// A slow change is running: a 16 dp spinner instead of the number,
  /// which changes only when the server answers (CA-17).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final tap = busy ? null : onTap;
    return Semantics(
      container: true,
      liveRegion: true,
      button: true,
      enabled: tap != null,
      label: busy ? l10n.updatingQuantity : l10n.quantityBoxLabel(quantity),
      onTap: tap,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(JivoRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('qty-edit-$id'),
          onTap: tap,
          child: SizedBox(
            width: double.infinity,
            height: kJivoMinTouchTarget,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      key: ValueKey('qty-busy-$id'),
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onPrimary,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$quantity',
                            key: ValueKey('qty-$id'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: JivoSpacing.xs),
                          Icon(Icons.edit_rounded, size: 18, color: onPrimary),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Removed {name}" with Undo after a line left the cart (the delete
/// button, or − at the minimum per order), also read out by screen readers.
/// Built before the change: the tile that started it may be gone by the
/// time the server answers, so it keeps the messenger, view and texts.
class CartRemovedNotice {
  CartRemovedNotice.of(BuildContext context)
    : _messenger = ScaffoldMessenger.of(context),
      _view = View.of(context),
      _direction = Directionality.of(context),
      _l10n = AppLocalizations.of(context);

  final ScaffoldMessengerState _messenger;
  final FlutterView _view;
  final TextDirection _direction;
  final AppLocalizations _l10n;

  /// Shows the notice for [name]. [restore] (null: nothing to undo, e.g. out
  /// of stock) puts the previous quantity back with the same controller
  /// call as ADD; a refusal is shown through the kept messenger.
  void show({
    required String name,
    required int variantId,
    Future<void> Function()? restore,
    Key? undoKey,
  }) {
    if (!_messenger.mounted) return;
    final text = _l10n.removedFromCart(name);
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: restore == null
              ? null
              : SnackBarAction(
                  key: undoKey,
                  label: _l10n.undo,
                  onPressed: () =>
                      _undo(restore, name: name, variantId: variantId),
                ),
        ),
      );
    unawaited(SemanticsService.sendAnnouncement(_view, text, _direction));
  }

  Future<void> _undo(
    Future<void> Function() restore, {
    required String name,
    required int variantId,
  }) async {
    String? problem;
    try {
      await restore();
    } on CartLimitException catch (e) {
      problem = _l10n.maxQtyReached(e.max);
    } catch (error) {
      if (!_messenger.mounted) return;
      problem = cartErrorText(
        _messenger.context,
        error,
        names: {variantId: name},
      );
    }
    if (problem == null || !_messenger.mounted) return;
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(problem)));
  }
}
