import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/catalog_models.dart';
import 'catalog_controllers.dart';

/// The full category tree (`03 §2.6`): each top-level category with its
/// sub-categories. Tapping one opens the product list.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabCategories),
        actions: [
          IconButton(
            tooltip: l10n.searchFieldHint,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: switch (categories) {
        AsyncData(:final value) when value.isEmpty => EmptyView(
          message: l10n.categoriesEmpty,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(categoriesProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: JivoSpacing.xl),
            children: [
              for (final top in value) _CategorySection(category: top),
            ],
          ),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
        _ => const SkeletonSemantics(
          child: Padding(
            padding: EdgeInsets.all(JivoSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 18, width: 140),
                SizedBox(height: JivoSpacing.md),
                SkeletonBox(height: 96, width: double.infinity),
                SizedBox(height: JivoSpacing.xl),
                SkeletonBox(height: 18, width: 120),
                SizedBox(height: JivoSpacing.md),
                SkeletonBox(height: 96, width: double.infinity),
              ],
            ),
          ),
        ),
      },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category});

  final ProductCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = [
      (
        label: l10n.allInCategory,
        sub: null as String?,
        image: category.imageUrl,
      ),
      for (final child in category.children)
        (label: child.name, sub: child.slug, image: child.imageUrl),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              category.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 96,
            mainAxisExtent: categoryTileExtent(context),
            crossAxisSpacing: JivoSpacing.sm,
            mainAxisSpacing: JivoSpacing.sm,
          ),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return CategoryTile(
              label: entry.label,
              imageUrl: entry.image,
              onTap: () =>
                  context.push(Routes.category(category.slug, sub: entry.sub)),
            );
          },
        ),
      ],
    );
  }
}

/// The height a [CategoryTile] needs at the current text scale.
double categoryTileExtent(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
  return 64 + JivoSpacing.xs + 2 * JivoSpacing.xs + 34 * scale;
}

/// Image and name (home grid and the categories tab).
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    required this.label,
    required this.onTap,
    this.imageUrl,
    super.key,
  });

  final String label;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(JivoRadii.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: JivoSpacing.xs),
        child: Column(
          children: [
            SizedBox(
              height: 64,
              width: 64,
              child: ProductImage(url: imageUrl, icon: Icons.category_outlined),
            ),
            const SizedBox(height: JivoSpacing.xs),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    ),
  );
}
