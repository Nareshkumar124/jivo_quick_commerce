import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/state_views.dart';
import '../../cart/presentation/cart_bar.dart';
import '../../location/presentation/delivery_controller.dart';
import '../../location/presentation/store_closed_banner.dart';
import '../domain/catalog_models.dart';
import 'catalog_controllers.dart';
import 'widgets/paged_product_grid.dart';

String sortLabel(AppLocalizations l10n, ProductSort sort) => switch (sort) {
  ProductSort.relevance => l10n.sortRelevance,
  ProductSort.priceLowToHigh => l10n.sortPriceLowHigh,
  ProductSort.priceHighToLow => l10n.sortPriceHighLow,
  ProductSort.discount => l10n.sortDiscount,
};

/// A category's products (`03 §2.6`): a left rail of sub-categories and a
/// product grid with sort and infinite scroll.
class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({required this.slug, this.sub, super.key});

  /// The category (top-level or sub-category) from the route.
  final String slug;

  /// The preselected sub-category.
  final String? sub;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  String? _selected;
  bool _selectionInitialised = false;
  ProductSort _sort = ProductSort.relevance;

  Future<void> _chooseSort() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<ProductSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<ProductSort>(
          groupValue: _sort,
          onChanged: (value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: JivoSpacing.gutter,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.sortBy,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              for (final option in ProductSort.values)
                RadioListTile<ProductSort>(
                  value: option,
                  title: Text(sortLabel(l10n, option)),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && choice != _sort) setState(() => _sort = choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tree = ref.watch(categoriesProvider);
    final store = ref.watch(deliveryProvider.select((s) => s.store));
    final found = tree.value == null
        ? null
        : findCategory(tree.value!, widget.slug);
    final top = found?.top;
    if (found != null && !_selectionInitialised) {
      _selectionInitialised = true;
      _selected = widget.sub ?? found.child?.slug;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(top?.name ?? ''),
        actions: [
          IconButton(
            tooltip: l10n.searchFieldHint,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      bottomNavigationBar: const CartBar(),
      body: switch (tree) {
        AsyncError(:final error) when tree.value == null => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        AsyncData() when top == null => EmptyView(message: l10n.productsEmpty),
        AsyncData() => Column(
          children: [
            if (store != null && !store.isOpen) StoreClosedBanner(store: store),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SubCategoryRail(
                    category: top!,
                    selected: _selected,
                    onSelected: (slug) => setState(() => _selected = slug),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: JivoSpacing.xs,
                          ),
                          child: TextButton.icon(
                            key: const Key('sort-button'),
                            onPressed: _chooseSort,
                            icon: const Icon(Icons.sort),
                            label: Text(
                              l10n.sortButton(sortLabel(l10n, _sort)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: PagedProductGrid(
                            query: CategoryQuery(_selected ?? top.slug, _sort),
                            emptyMessage: l10n.productsEmpty,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _ => const ProductGridSkeleton(),
      },
    );
  }
}

class _SubCategoryRail extends StatelessWidget {
  const _SubCategoryRail({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  static const width = 76.0;

  final ProductCategory category;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = [
      (
        slug: null as String?,
        label: l10n.allInCategory,
        image: category.imageUrl,
      ),
      for (final child in category.children)
        (slug: child.slug, label: child.name, image: child.imageUrl),
    ];
    return SizedBox(
      width: width,
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final entry = entries[i];
          final isSelected = entry.slug == selected;
          return Semantics(
            selected: isSelected,
            button: true,
            child: InkWell(
              key: ValueKey('rail-${entry.slug ?? 'all'}'),
              onTap: () => onSelected(entry.slug),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  vertical: JivoSpacing.sm,
                  horizontal: JivoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primaryContainer : null,
                  border: Border(
                    right: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: 44,
                      child: ProductImage(
                        url: entry.image,
                        icon: Icons.category_outlined,
                      ),
                    ),
                    const SizedBox(height: JivoSpacing.xs),
                    Text(
                      entry.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
