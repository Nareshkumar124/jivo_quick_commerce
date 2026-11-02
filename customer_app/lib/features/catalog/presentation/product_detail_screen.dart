import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/state_views.dart';
import '../../cart/presentation/add_stepper.dart';
import '../../cart/presentation/cart_bar.dart';
import '../domain/catalog_models.dart';
import 'catalog_controllers.dart';
import 'widgets/price_tags.dart';
import 'widgets/product_tile.dart';

/// Product detail (`03 §2.6`): gallery with zoom, variant chips with price
/// and stock, ADD stepper, "You save", highlights, description, label
/// information and similar products.
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final product = ref.watch(productDetailProvider(slug));
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.searchFieldHint,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      bottomNavigationBar: const CartBar(),
      body: switch (product) {
        AsyncData(:final value) => _ProductBody(product: value),
        AsyncError(:final error)
            when ApiError.from(error).code == ApiErrorCode.notFound =>
          EmptyView(
            message: l10n.productNotFound,
            icon: Icons.inventory_2_outlined,
          ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(productDetailProvider(slug)),
        ),
        _ => const SkeletonSemantics(
          child: Padding(
            padding: EdgeInsets.all(JivoSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 280, width: double.infinity),
                SizedBox(height: JivoSpacing.lg),
                SkeletonBox(height: 22, width: 220),
                SizedBox(height: JivoSpacing.md),
                SkeletonBox(height: 40, width: 160),
                SizedBox(height: JivoSpacing.lg),
                SkeletonBox(height: 48, width: double.infinity),
              ],
            ),
          ),
        ),
      },
    );
  }
}

class _ProductBody extends StatefulWidget {
  const _ProductBody({required this.product});

  final ProductDetail product;

  @override
  State<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends State<_ProductBody> {
  late CatalogVariant _variant = widget.product.defaultVariant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final product = widget.product;
    final variant = _variant;
    final discount = variant.discountPercent;
    final unitsLeft = variant.lowStockUnits;
    final unitPrice = variant.unitPrice;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(
        top: JivoSpacing.xl,
        bottom: JivoSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    final label = product.label;
    final infoRows = [
      (l10n.ingredients, label.ingredients),
      (l10n.shelfLife, label.shelfLife),
      (l10n.storageInfo, label.storageInstructions),
      (l10n.countryOfOrigin, label.countryOfOrigin),
      (l10n.manufacturedBy, label.manufacturer),
      (l10n.marketedBy, label.marketer),
      (l10n.importedBy, label.importer),
      (l10n.consumerCare, label.consumerCare),
      (l10n.fssaiLicence, label.fssaiLicenseNo),
    ].where((row) => row.$2.trim().isNotEmpty).toList();
    final nutrition = label.nutrition;

    return ListView(
      padding: const EdgeInsets.only(bottom: JivoSpacing.xl),
      children: [
        _Gallery(
          key: ValueKey('gallery-for-${variant.id}'),
          urls: variant.images,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: JivoSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        product.name,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SizedBox(width: JivoSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: VegMark(isVeg: product.isVeg, size: 18),
                  ),
                ],
              ),
              Text(
                product.brand,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (product.shortDescription.trim().isNotEmpty) ...[
                const SizedBox(height: JivoSpacing.xs),
                Text(product.shortDescription),
              ],
              if (product.variants.length > 1) ...[
                heading(l10n.packSize),
                Wrap(
                  spacing: JivoSpacing.sm,
                  runSpacing: JivoSpacing.sm,
                  children: [
                    for (final v in product.variants)
                      ChoiceChip(
                        key: ValueKey('variant-${v.id}'),
                        selected: v.id == variant.id,
                        onSelected: (_) => setState(() => _variant = v),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(v.name),
                            Text(
                              v.inStock
                                  ? formatRupees(v.sellingPrice)
                                  : l10n.outOfStock,
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: JivoSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: MergeSemantics(
                      child: PriceLine(
                        price: variant.sellingPrice,
                        mrp: variant.mrp,
                        large: true,
                      ),
                    ),
                  ),
                  if (discount > 0) DiscountBadge(percent: discount),
                ],
              ),
              if (unitPrice != null)
                Text(
                  l10n.unitPrice(formatRupees(unitPrice.amount), unitPrice.per),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (!isZeroAmount(variant.discountAmount))
                Text(
                  l10n.youSave(formatRupees(variant.discountAmount)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.jivoColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (unitsLeft != null)
                Text(
                  l10n.onlyLeft(unitsLeft),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: JivoSpacing.md),
              AddStepper(
                key: ValueKey('pdp-${variant.id}'),
                variant: variant,
                productName: product.name,
              ),
              if (product.highlights.isNotEmpty) ...[
                heading(l10n.highlights),
                for (final line in product.highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: JivoSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExcludeSemantics(child: Text('•  ')),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
              ],
              if (product.description.trim().isNotEmpty) ...[
                heading(l10n.description),
                Text(product.description),
              ],
              if (infoRows.isNotEmpty || nutrition != null)
                heading(l10n.productInfo),
              for (final (name, value) in infoRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(value),
                      ],
                    ),
                  ),
                ),
              if (nutrition != null) _NutritionTableView(table: nutrition),
            ],
          ),
        ),
        if (product.similar.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              JivoSpacing.gutter,
              JivoSpacing.xl,
              JivoSpacing.gutter,
              JivoSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.similarProducts,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          ProductRail(items: product.similar),
        ],
      ],
    );
  }
}

/// The nutrition table as printed on the label: a heading row of columns,
/// then one row per nutrient (sub-rows indented).
class _NutritionTableView extends StatelessWidget {
  const _NutritionTableView({required this.table});

  final NutritionTable table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget cell(String text, {bool bold = false, double indent = 0}) => Padding(
      padding: EdgeInsets.fromLTRB(
        JivoSpacing.sm + indent,
        JivoSpacing.sm,
        JivoSpacing.sm,
        JivoSpacing.sm,
      ),
      child: Text(
        text,
        style: bold ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: JivoSpacing.sm),
        Text(
          AppLocalizations.of(context).nutritionInfo,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: JivoSpacing.xs),
        Table(
          border: TableBorder.all(color: theme.dividerColor),
          columnWidths: const {0: FlexColumnWidth(1.4)},
          children: [
            TableRow(
              children: [
                cell(''),
                for (final column in table.columns) cell(column, bold: true),
              ],
            ),
            for (final row in table.rows)
              TableRow(
                children: [
                  cell(row.name, indent: row.isSubRow ? JivoSpacing.lg : 0),
                  for (var i = 0; i < table.columns.length; i++)
                    cell(i < row.values.length ? row.values[i] : ''),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Swipeable images with page dots; tap opens a zoomable full-screen view.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.urls, super.key});

  final List<String> urls;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  void _openZoom(int index) {
    final urls = widget.urls;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) =>
            _ZoomView(urls: urls.isEmpty ? const [null] : urls, initial: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final urls = widget.urls.isEmpty ? const <String?>[null] : widget.urls;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            itemCount: urls.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, i) => Semantics(
              button: true,
              label: l10n.galleryImage(i + 1, urls.length),
              child: GestureDetector(
                key: ValueKey('gallery-$i'),
                onTap: () => _openZoom(i),
                child: Padding(
                  padding: const EdgeInsets.all(JivoSpacing.gutter),
                  child: ProductImage(url: urls[i]),
                ),
              ),
            ),
          ),
        ),
        if (urls.length > 1)
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  Container(
                    margin: const EdgeInsets.all(3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ZoomView extends StatefulWidget {
  const _ZoomView({required this.urls, required this.initial});

  final List<String?> urls;
  final int initial;

  @override
  State<_ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<_ZoomView> {
  late final _controller = PageController(initialPage: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.urls.length,
      itemBuilder: (context, i) => InteractiveViewer(
        key: ValueKey('zoom-$i'),
        maxScale: 4,
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: ProductImage(url: widget.urls[i]),
          ),
        ),
      ),
    ),
  );
}
