import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../cart/presentation/cart_bar.dart';
import 'catalog_controllers.dart';
import 'widgets/paged_product_grid.dart';

/// A collection ("Bestsellers", "Offers", ...) as a product grid.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = CollectionQuery(slug);
    final title = ref.watch(
      pagedProductsProvider(query).select((s) => s.value?.title),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? ''),
        actions: [
          IconButton(
            tooltip: l10n.searchFieldHint,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      bottomNavigationBar: const CartBar(),
      body: PagedProductGrid(query: query, emptyMessage: l10n.collectionEmpty),
    );
  }
}
