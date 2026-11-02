import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../app/redirect.dart';
import '../../../../app/repositories.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/product_image.dart';
import '../../../cart/presentation/add_stepper.dart';
import '../../../cart/presentation/cart_controller.dart';
import '../../domain/catalog_models.dart';
import 'price_tags.dart';

const _imageHeight = 110.0;
const _padding = 6.0;

/// The height a [ProductTile] needs at the current text scale, so grids and
/// rails grow with the system font size instead of overflowing.
double productTileExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  // Fixed: padding, image, gaps, the 48 dp stepper and slack. Text (at
  // 14 sp = 1.0): two name lines (40), variant or options (16), stock label
  // (16) and the price, which may wrap the MRP onto a second line (20 + 16).
  const fixed = 2 * _padding + _imageHeight + 2 * JivoSpacing.sm + 48 + 6;
  return fixed + 108 * scale;
}

/// A product tile (`03 §2.5`): image, discount badge, veg mark, name, the
/// default variant, price with struck-out MRP, stock label and the ADD
/// stepper. Out-of-stock tiles are greyed out. With several variants, ADD
/// opens a variant picker.
class ProductTile extends StatelessWidget {
  const ProductTile({required this.product, super.key});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final variant = product.defaultVariant;
    final discount = variant.discountPercent;
    final unitsLeft = variant.lowStockUnits;
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _imageHeight,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: ProductImage(url: variant.imageUrl ?? product.imageUrl),
              ),
              if (discount > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  child: DiscountBadge(percent: discount),
                ),
              Positioned(
                right: 4,
                top: 4,
                child: VegMark(isVeg: product.isVeg),
              ),
            ],
          ),
        ),
        const SizedBox(height: JivoSpacing.sm),
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          product.hasOptions
              ? l10n.variantOptions(variant.name, product.variants.length)
              : variant.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (unitsLeft != null)
          Text(
            l10n.onlyLeft(unitsLeft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );

    return Opacity(
      opacity: product.inStock ? 1 : 0.6,
      child: Card(
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
                MergeSemantics(child: info),
                const Spacer(),
                MergeSemantics(
                  child: PriceLine(
                    price: variant.sellingPrice,
                    mrp: variant.mrp,
                  ),
                ),
                const SizedBox(height: JivoSpacing.sm),
                if (product.hasOptions)
                  _OptionsControl(product: product)
                else
                  AddStepper(variant: variant, productName: product.name),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    return QuantityStepper(
      id: 'product-${product.id}',
      quantity: total,
      productName: product.name,
      onDecrement: pick,
      onIncrement: pick,
    );
  }
}

/// The variant picker: each pack size with its price, stock and stepper.
Future<void> showVariantPicker(BuildContext context, CatalogProduct product) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context);
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
                child: Row(
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
              ),
          ],
        );
      },
    );

/// A horizontal rail of tiles (home collections, similar products).
class ProductRail extends StatelessWidget {
  const ProductRail({required this.items, super.key});

  final List<CatalogProduct> items;

  static const tileWidth = 150.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: productTileExtent(context),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: JivoSpacing.sm),
      itemBuilder: (_, i) => SizedBox(
        width: tileWidth,
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
      maxCrossAxisExtent: 200,
      mainAxisExtent: productTileExtent(context),
      crossAxisSpacing: JivoSpacing.sm,
      mainAxisSpacing: JivoSpacing.sm,
    ),
    itemCount: items.length,
    itemBuilder: (_, i) => ProductTile(product: items[i]),
  );
}
