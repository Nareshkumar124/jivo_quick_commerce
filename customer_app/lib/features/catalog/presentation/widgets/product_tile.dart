import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../app/redirect.dart';
import '../../../../app/theme.dart';
import '../../../../app/repositories.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../cart/presentation/add_stepper.dart';
import '../../../cart/presentation/cart_controller.dart';
import '../../domain/catalog_models.dart';
import 'price_tags.dart';
import 'price_tiers_table.dart';

const _imageHeight = 128.0;
const _padding = 12.0;

/// The height a [ProductTile] needs at the current text scale, so grids and
/// rails grow with the system font size instead of overflowing.
/// [minQtyHint]: some tile shows the "Min 5" hint (see [needsMinQtyHint]).
double productTileExtent(BuildContext context, {bool minQtyHint = false}) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  // Fixed: padding, image well, gaps and the 48 dp control. Text (at 14 sp =
  // 1.0): name (40), pack-size pill (16), price (28), bulk pill (16), "Only
  // N left" (16), plus the "Min 5" line (16) when it wraps.
  const fixed = 2 * _padding + _imageHeight + 8 + 4 + 6 + 4 + 8 + 48 + 8;
  return fixed + (minQtyHint ? 132 : 116) * scale;
}

/// Two columns on phones; one column from 1.5x text (CA-14).
double productGridMaxExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  return 200 * (scale >= 1.5 ? scale : 1);
}

/// Some tile in [items] shows the "Min 5" line: its row needs the room.
bool needsMinQtyHint(List<CatalogProduct> items) =>
    items.any((p) => p.defaultVariant.hasMinQty);

/// The last (cheapest) volume price, when it differs from the selling
/// price: all strings and counts are the server's.
({String price, int from})? bulkPriceOf(CatalogVariant variant) {
  if (variant.priceTiers.length < 2) return null;
  final last = priceTierRows(variant.priceTiers).last;
  if (displayRupees(last.price) == displayRupees(variant.sellingPrice)) {
    return null;
  }
  return (price: last.price, from: last.from);
}

/// A product card (`03 §2.5`): image well, discount badge, veg mark, name,
/// pack size, bold price per carton, the gold bulk-price label, stock label
/// and the gold ADD button. Out-of-stock cards grey only the image and show
/// the stock pill instead of ADD (CA-11). With several
/// variants, ADD opens a variant picker.
class ProductTile extends StatelessWidget {
  const ProductTile({required this.product, super.key});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cc = context.customerColors;
    final variant = product.defaultVariant;
    final discount = variant.discountPercent;
    final unitsLeft = variant.lowStockUnits;
    final bulk = bulkPriceOf(variant);
    final selling = displayRupees(variant.sellingPrice);
    final listed = displayRupees(variant.mrp);
    final pill = BoxDecoration(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(JivoRadii.pill),
    );
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                  padding: const EdgeInsets.all(8),
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
                child: VegMark(isVeg: product.isVeg),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
    final pills = Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MergeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pill,
            child: Text(
              product.hasOptions
                  ? l10n.variantOptions(variant.name, product.variants.length)
                  : variant.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        if (variant.hasMinQty) MinQtyHint(variant: variant, compact: true),
      ],
    );
    final bottom = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    l10n.perCarton,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (listed != selling)
              Text(
                listed,
                semanticsLabel: l10n.mrpSemantics(listed),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
        if (bulk != null) ...[
          const SizedBox(height: 4),
          Container(
            key: ValueKey('bulk-${product.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cc.goldLight,
              borderRadius: BorderRadius.circular(JivoRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_down_rounded, size: 16, color: cc.onGold),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l10n.bulkPriceFrom(displayRupees(bulk.price), bulk.from),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cc.onGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (unitsLeft != null)
          Text(
            l10n.onlyLeft(unitsLeft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );

    // Out of stock: only the image is greyed (CA-11); every text keeps its
    // full contrast and the stock pill replaces ADD.
    return Card(
      key: ValueKey('tile-${product.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.product(product.slug)),
        child: Padding(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(child: top),
              const SizedBox(height: 4),
              pills,
              MergeSemantics(child: bottom),
              const Spacer(),
              const SizedBox(height: 8),
              if (product.hasOptions)
                _OptionsControl(product: product)
              else
                AddStepper(variant: variant, productName: product.name),
            ],
          ),
        ),
      ),
    );
  }
}

/// Greys a product image (saturation 0, half opacity) when the product is
/// out of stock. Only the image: text on the card keeps full contrast
/// (CA-11).
class OutOfStockImage extends StatelessWidget {
  const OutOfStockImage({
    required this.outOfStock,
    required this.child,
    super.key,
  });

  final bool outOfStock;
  final Widget child;

  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) => outOfStock
      ? Opacity(
          opacity: 0.5,
          child: ColorFiltered(colorFilter: _greyscale, child: child),
        )
      : child;
}

/// ADD (or the total in the cart) for a product with several variants:
/// every change goes through the variant picker.
class _OptionsControl extends ConsumerWidget {
  const _OptionsControl({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    if (total == 0) {
      return AddButton(
        key: ValueKey('add-product-${product.id}'),
        semanticsLabel: AppLocalizations.of(context)
            .addToCartSemantics(product.name),
        onPressed: pick,
      );
    }
    // Per-variant quantities are typed in the picker.
    return QuantityBox(
      id: 'product-${product.id}',
      quantity: total,
      onTap: pick,
    );
  }
}

/// The variant picker: each pack size with its price, stock and stepper,
/// and its wholesale rates when the server sends `price_tiers`.
Future<void> showVariantPicker(BuildContext context, CatalogProduct product) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context);
        final tiered = product.variants.any((v) => v.hasPriceTiers);
        return ListView(
          key: const Key('variant-picker'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            JivoSpacing.gutter,
            0,
            JivoSpacing.gutter,
            JivoSpacing.xl,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(product.name, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: JivoSpacing.md),
            for (final variant in product.variants)
              Padding(
                padding: const EdgeInsets.only(bottom: JivoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MergeSemantics(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variant.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                PriceLine(
                                  price: variant.sellingPrice,
                                  mrp: variant.mrp,
                                ),
                                if (variant.discountPercent > 0)
                                  Text(
                                    l10n.discountOff(variant.discountPercent),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: context.jivoColors.success,
                                    ),
                                  ),
                                if (variant.lowStockUnits != null)
                                  Text(
                                    l10n.onlyLeft(variant.lowStockUnits!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                MinQtyHint(variant: variant),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: JivoSpacing.md),
                        SizedBox(
                          width: 128,
                          child: AddStepper(
                            variant: variant,
                            productName: product.name,
                          ),
                        ),
                      ],
                    ),
                    if (variant.hasPriceTiers) ...[
                      const SizedBox(height: JivoSpacing.xs),
                      PriceTiersCompact(
                        key: ValueKey('picker-tiers-${variant.id}'),
                        tiers: variant.priceTiers,
                      ),
                    ],
                  ],
                ),
              ),
            if (tiered)
              Text(
                l10n.priceTierNote,
                key: const Key('picker-tiers-note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        );
      },
    );

/// A horizontal rail of tiles (home collections, similar products).
class ProductRail extends StatelessWidget {
  const ProductRail({required this.items, super.key});

  final List<CatalogProduct> items;

  static const tileWidth = 160.0;

  /// Wider tiles at large text, up to 1.5x (CA-14), so names stay readable.
  static double tileWidthFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return tileWidth * scale.clamp(1.0, 1.5);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: productTileExtent(context, minQtyHint: needsMinQtyHint(items)),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: JivoSpacing.sm),
      itemBuilder: (_, i) => SizedBox(
        width: tileWidthFor(context),
        child: ProductTile(product: items[i]),
      ),
    ),
  );
}

/// The tile grid as a sliver (product list, collection, search results).
class SliverProductGrid extends StatelessWidget {
  const SliverProductGrid({required this.items, super.key});

  final List<CatalogProduct> items;

  @override
  Widget build(BuildContext context) => SliverGrid.builder(
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: productGridMaxExtent(context),
      mainAxisExtent: productTileExtent(
        context,
        minQtyHint: needsMinQtyHint(items),
      ),
      crossAxisSpacing: JivoSpacing.md,
      mainAxisSpacing: JivoSpacing.md,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => ProductTile(product: items[i]),
  );
}
