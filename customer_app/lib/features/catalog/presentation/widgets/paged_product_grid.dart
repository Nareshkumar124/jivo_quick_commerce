import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../location/presentation/delivery_controller.dart';
import '../../../../shared/widgets/skeletons.dart';
import '../../../../shared/widgets/state_views.dart';
import '../catalog_controllers.dart';
import 'product_tile.dart';

/// A product grid with infinite scroll and the loading (skeleton), empty
/// and error-with-retry states (`03 §2.6`, `§4`).
class PagedProductGrid extends ConsumerWidget {
  const PagedProductGrid({
    required this.query,
    required this.emptyMessage,
    this.emptyAction,
    super.key,
  });

  final ProductQuery query;
  final String emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = pagedProductsProvider(query);
    final storeId = ref.watch(currentStoreIdProvider);
    ref.listen(provider, (previous, next) {
      if (isFailedRefresh(previous, next) &&
          next.value?.storeId == ref.read(currentStoreIdProvider)) {
        showRefreshFailed(context, () => ref.invalidate(provider));
      }
    });
    final state = ref.watch(provider);
    // This store's products, also when a refresh failed (CA-03); never
    // another store's (prices and stock are per store).
    final shown = switch (state) {
      AsyncData(:final value) => value,
      AsyncError(:final value?) when value.storeId == storeId => value,
      _ => null,
    };
    return switch (state) {
      _ when shown != null && shown.items.isEmpty => EmptyView(
        message: emptyMessage,
        icon: Icons.search_off,
        action: emptyAction,
      ),
      _ when shown != null => RefreshIndicator(
        onRefresh: () => refreshQuietly(ref.refresh(provider.future)),
        child: CustomScrollView(
          key: const Key('product-grid'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(JivoSpacing.sm),
              sliver: SliverProductGrid(items: shown.items),
            ),
            SliverToBoxAdapter(
              child: _LoadMoreFooter(
                state: shown,
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
              ),
            ),
          ],
        ),
      ),
      AsyncError(:final error) => ErrorRetryView(
        error: error,
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const ProductGridSkeleton(),
    };
  }
}

/// Built only when scrolled near the end (slivers are lazy), so building it
/// is the "load more" trigger. A failed page shows a retry button.
class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state, required this.onLoadMore});

  final PagedProducts state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(JivoSpacing.lg),
        child: Column(
          children: [
            Text(AppLocalizations.of(context).loadMoreFailed),
            TextButton(
              onPressed: onLoadMore,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      );
    }
    if (!state.hasMore) return const SizedBox(height: 96);
    if (!state.loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
    }
    return const Padding(
      padding: EdgeInsets.all(JivoSpacing.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
