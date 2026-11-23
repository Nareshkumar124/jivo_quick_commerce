import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/product_image.dart';
import '../../cart/presentation/add_stepper.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/quantity_dialog.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/widgets/price_tags.dart';
import '../../catalog/presentation/widgets/product_tile.dart';

const _padding = 8.0;
const _imageHeight = 112.0;

/// Text scale of the current context (1.0 = the phone's default size).
double _scaleOf(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;

/// The height every [HomeProductCard] in [items] gets, so one rail or grid
/// row lines up and grows with the system font size instead of
/// overflowing. A row reserves room for an optional line (MRP, "Min 5",
/// bulk price, "Only N left") only when some card in [items] shows it.
double homeCardExtent(BuildContext context, List<CatalogProduct> items) {
  final scale = _scaleOf(context);
  bool any(bool Function(CatalogVariant v) test) =>
      items.any((p) => test(p.defaultVariant));
  // Fixed: padding, image well, gaps and the 48 dp control.
  const fixed =
      2 * _padding + _imageHeight + 8 + 2 + 6 + 8 + kJivoMinTouchTarget;
  // Text at 1.0: name (2 lines), pack size, price; optional lines below.
  var text = 42.0 + 18 + 28;
  if (any((v) => displayRupees(v.mrp) != displayRupees(v.sellingPrice))) {
    text += 18; // the struck-out MRP wraps under the price on narrow cards
  }
  if (any((v) => v.hasMinQty)) text += 18;
  if (any((v) => bulkPriceOf(v) != null)) text += 22;
  if (any((v) => v.lowStockUnits != null)) text += 18;
  return fixed + text * scale;
}

/// A compact home product card (home redesign, 2026-11-21): image well,
/// name, pack size, the price in bold, the wholesale price when the server
/// sends `price_tiers`, and a green ADD that turns into − qty +. Every
/// value is the server's; nothing is calculated here. Other screens keep
/// [ProductTile].
class HomeProductCard extends StatelessWidget {
  const HomeProductCard({required this.product, super.key});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cc = context.customerColors;
    final variant = product.defaultVariant;
    final discount = variant.discountPercent;
    final unitsLeft = variant.lowStockUnits;
    final bulk = bulkPriceOf(variant);
    final selling = displayRupees(variant.sellingPrice);
    final listed = displayRupees(variant.mrp);
    final muted = scheme.onSurfaceVariant;

    final image = Container(
      height: _imageHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cc.imageWell,
        borderRadius: BorderRadius.circular(JivoRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: OutOfStockImage(
                outOfStock: !product.inStock,
                child: ProductImage(
                  url: variant.imageUrl ?? product.imageUrl,
                  fit: BoxFit.contain,
                  onWell: true,
                ),
              ),
            ),
          ),
          if (discount > 0)
            Positioned(
              left: 6,
              top: 6,
              child: DiscountBadge(percent: discount),
            ),
          Positioned(
            right: 6,
            top: 6,
            child: VegMark(isVeg: product.isVeg, size: 14),
          ),
        ],
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              product.hasOptions
                  ? l10n.variantOptions(variant.name, product.variants.length)
                  : variant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            if (variant.hasMinQty) MinQtyHint(variant: variant, compact: true),
          ],
        ),
      ],
    );

    final price = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: JivoSpacing.xs,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    selling,
                    semanticsLabel: l10n.priceSemantics(selling),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    l10n.perCarton,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
            if (listed != selling)
              Text(
                listed,
                semanticsLabel: l10n.mrpSemantics(listed),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        if (bulk != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              key: ValueKey('bulk-${product.id}'),
              children: [
                Icon(
                  Icons.trending_down_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n.bulkPriceFrom(displayRupees(bulk.price), bulk.from),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (unitsLeft != null)
          Text(
            l10n.onlyLeft(unitsLeft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.error),
          ),
      ],
    );

    return Material(
      key: ValueKey('tile-${product.id}'),
      color: scheme.surfaceContainerLowest,
      elevation: 1,
      shadowColor: cc.softShadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JivoRadii.lg),
        side: BorderSide(color: cc.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.product(product.slug)),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [image, const SizedBox(height: 8), details],
                ),
              ),
              const SizedBox(height: 6),
              MergeSemantics(child: price),
              const Spacer(),
              const SizedBox(height: 8),
              HomeCartControl(product: product),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal rail of [HomeProductCard]s (home collections, "Previously
/// bought").
class HomeProductRail extends StatelessWidget {
  const HomeProductRail({required this.items, super.key});

  final List<CatalogProduct> items;

  /// Wider cards at large text, up to 1.5x (CA-14).
  static double cardWidthFor(BuildContext context) =>
      152 * _scaleOf(context).clamp(1.0, 1.5);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: homeCardExtent(context, items),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: JivoSpacing.md),
      itemBuilder: (_, i) => SizedBox(
        width: cardWidthFor(context),
        child: HomeProductCard(product: items[i]),
      ),
    ),
  );
}

/// The card's cart control. One pack size: green ADD, then − qty +. Several
/// pack sizes: ADD (then the total) opens the existing variant picker.
/// Staging and prod without the cart show "Cart coming soon".
class HomeCartControl extends ConsumerWidget {
  const HomeCartControl({required this.product, super.key});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!product.hasOptions) {
      return HomeQuantityStepper(
        variant: product.defaultVariant,
        productName: product.name,
      );
    }
    if (!ref.watch(cartAvailableProvider)) {
      return product.inStock
          ? const CartComingSoonLabel()
          : const OutOfStockLabel();
    }
    final total = ref.watch(
      cartProvider.select((c) => c.quantityOfProduct(product)),
    );
    void pick() => showVariantPicker(context, product);
    if (total == 0 && !product.inStock) return const OutOfStockLabel();
    return _swap(
      context,
      total == 0
          ? HomeAddButton(
              key: ValueKey('add-product-${product.id}'),
              semanticsLabel: AppLocalizations.of(context)
                  .addToCartSemantics(product.name),
              onPressed: pick,
            )
          : QuantityBox(
              key: const ValueKey('home-qty-box'),
              id: 'product-${product.id}',
              quantity: total,
              onTap: pick,
            ),
    );
  }
}

/// ADD fades into the stepper (`motion.qtySwap`, 200 ms); no motion when
/// the phone asks for none.
Widget _swap(BuildContext context, Widget child) => AnimatedSwitcher(
  duration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200),
  switchInCurve: Curves.easeOutCubic,
  transitionBuilder: (child, animation) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.0).animate(animation),
      child: child,
    ),
  ),
  child: child,
);

/// ADD, then − qty + for one variant. Every change is the cart
/// controller's `setVariantQuantity`, which keeps the minimum per order:
/// ADD asks for 1 and the controller raises it to `min_qty_per_order`
/// (e.g. 5 cartons); − below the minimum removes the line; + stops at
/// `orderable_quantity` with the usual message. Tapping the number opens
/// the existing "Enter quantity" dialog for bulk orders. Taps are ignored
/// while a change for this variant is in flight.
class HomeQuantityStepper extends ConsumerWidget {
  const HomeQuantityStepper({
    required this.variant,
    required this.productName,
    super.key,
  });

  final CatalogVariant variant;
  final String productName;

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
    if (quantity == 0 && !variant.inStock) return const OutOfStockLabel();
    final cart = ref.read(cartProvider.notifier);
    final l10n = AppLocalizations.of(context);

    Future<void> set(int target) => runCartChange(
      context,
      () => cart.setVariantQuantity(variant, target, productName: productName),
      names: {variant.id: '$productName ${variant.name}'},
    );

    // − at the minimum per order removes the line: say so, with Undo
    // (the previous quantity, through the same controller call).
    Future<void> minus() async {
      if (quantity - 1 >= cart.minimumFor(variant)) return set(quantity - 1);
      final notice = CartRemovedNotice.of(context);
      final container = ProviderScope.containerOf(context, listen: false);
      await set(quantity - 1);
      if (container.read(cartProvider).quantityOf(variant.id) != 0) return;
      notice.show(
        name: '$productName ${variant.name}',
        variantId: variant.id,
        undoKey: ValueKey('home-undo-${variant.id}'),
        restore: () => cart.setVariantQuantity(
          variant,
          quantity,
          productName: productName,
        ),
      );
    }

    Future<void> type() async {
      final typed = await showQuantityDialog(
        context,
        current: quantity,
        initial: quantity,
        max: variant.maxSelectable,
        min: variant.minQty,
      );
      if (typed == null || !context.mounted) return;
      await set(typed);
    }

    return DelayedPending(
      pending: pending,
      builder: (context, slow) => _swap(
        context,
        quantity == 0
            ? HomeAddButton(
                key: ValueKey('add-${variant.id}'),
                semanticsLabel: l10n.addToCartSemantics(productName),
                busy: slow,
                onPressed: pending ? null : () => set(1),
              )
            : QuantityStepper(
                key: const ValueKey('home-stepper'),
                id: '${variant.id}',
                name: productName,
                quantity: quantity,
                busy: slow,
                onMinus: pending ? null : minus,
                onPlus: pending ? null : () => set(quantity + 1),
                onType: pending ? null : type,
              ),
      ),
    );
  }
}

/// The home ADD: a pale-mint pill with a green label and a thin green edge,
/// 48 dp tall, the full width of its slot.
class HomeAddButton extends StatelessWidget {
  const HomeAddButton({
    required this.semanticsLabel,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String semanticsLabel;
  final VoidCallback? onPressed;

  /// A slow change is running: a spinner instead of "ADD" (CA-17).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.primary;
    final cc = context.customerColors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: busy
          ? AppLocalizations.of(context).updatingQuantity
          : semanticsLabel,
      liveRegion: busy,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: cc.softTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JivoRadii.md),
          side: BorderSide(color: green),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: double.infinity,
            height: kJivoMinTouchTarget,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: green,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: green),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context).addToCart,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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

/// − qty + on solid green, 48 dp tall (home cards and cart lines). The −
/// and + targets are 48 dp wide when the slot allows (about 40 dp at the
/// narrowest 320 dp grid); the number in the middle opens "Enter quantity".
/// Only draws: the callbacks make the cart changes.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.id,
    required this.name,
    required this.quantity,
    required this.busy,
    required this.onMinus,
    required this.onPlus,
    required this.onType,
    super.key,
  });

  final String id;
  final String name;
  final int quantity;
  final bool busy;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback? onType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onGreen = theme.colorScheme.onPrimary;
    Widget side({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
      required double width,
    }) => Semantics(
      button: true,
      enabled: onTap != null && !busy,
      label: label,
      excludeSemantics: true,
      onTap: busy ? null : onTap,
      child: InkWell(
        key: key,
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: width,
          height: kJivoMinTouchTarget,
          child: Icon(icon, size: 20, color: onGreen),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 3 * kJivoMinTouchTarget;
        final sideWidth = (width / 3).clamp(36.0, kJivoMinTouchTarget);
        return Material(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(JivoRadii.md),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: kJivoMinTouchTarget,
            child: Row(
              children: [
                side(
                  key: ValueKey('step-minus-$id'),
                  icon: Icons.remove_rounded,
                  label: l10n.decreaseQuantitySemantics(name),
                  onTap: onMinus,
                  width: sideWidth,
                ),
                Expanded(
                  child: Semantics(
                    container: true,
                    liveRegion: true,
                    button: true,
                    enabled: onType != null && !busy,
                    label: busy
                        ? l10n.updatingQuantity
                        : l10n.quantityBoxLabel(quantity),
                    onTap: busy ? null : onType,
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('qty-edit-$id'),
                      onTap: busy ? null : onType,
                      child: SizedBox(
                        height: kJivoMinTouchTarget,
                        child: Center(
                          child: busy
                              ? SizedBox.square(
                                  key: ValueKey('qty-busy-$id'),
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: onGreen,
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Text(
                                      '$quantity',
                                      key: ValueKey('qty-$id'),
                                      maxLines: 1,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: onGreen,
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                side(
                  key: ValueKey('step-plus-$id'),
                  icon: Icons.add_rounded,
                  label: l10n.increaseQuantitySemantics(name),
                  onTap: onPlus,
                  width: sideWidth,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
