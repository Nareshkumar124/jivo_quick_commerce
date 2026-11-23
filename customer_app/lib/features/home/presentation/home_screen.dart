import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../catalog/presentation/widgets/paged_product_grid.dart';
import '../../catalog/presentation/widgets/product_tile.dart'
    show productGridMaxExtent;
import '../../location/presentation/delivery_controller.dart';
import '../../location/presentation/location_options.dart';
import '../../location/presentation/store_closed_banner.dart';
import '../../orders/presentation/active_order_card.dart';
import '../../orders/presentation/pending_payment.dart';
import 'banner_carousel.dart';
import 'home_header.dart';
import 'home_product_card.dart';

/// Home (`03 §2.5`, redesign 2026-11-21): a compact delivery header,
/// search, the featured banners, a category row, collection rails,
/// "Previously bought" and all products. Pull to refresh reloads home and
/// re-checks serviceability.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notice = ref.read(pendingNoticeProvider.notifier).take();
      if (notice == AppNotice.deletionCancelled) {
        showMessage(
          context,
          AppLocalizations.of(context).deletionCancelledNotice,
        );
      }
    });
  }

  Future<void> _refresh() async {
    unawaited(ref.read(pendingPaymentProvider.notifier).check());
    await ref.read(deliveryProvider.notifier).refresh();
    ref.invalidate(homeFeedProvider);
    try {
      await ref.read(homeFeedProvider.future);
    } catch (_) {
      // Shown by the error state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final delivery = ref.watch(deliveryProvider);
    // CA-03: a failed pull-to-refresh keeps the feed and says so. Only with
    // a store: listening starts the feed, and there is none to load without.
    if (delivery.store != null) {
      ref.listen(homeFeedProvider, (previous, next) {
        if (isFailedRefresh(previous, next) &&
            next.value?.store?.id == ref.read(currentStoreIdProvider)) {
          showRefreshFailed(context, () => ref.invalidate(homeFeedProvider));
        }
      });
    }
    // The feed carries the store's live status; until it loads, the
    // serviceability check's.
    final store = delivery.store == null
        ? null
        : ref.watch(homeFeedProvider).value?.store ?? delivery.store;
    return Scaffold(
      key: const Key('home-screen'),
      // No top SafeArea: the header paints behind the status bar and adds
      // the top inset itself.
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: HomeHeader(delivery: delivery)),
              SliverToBoxAdapter(
                child: HomeSearchBar(hint: l10n.homeSearchHint),
              ),
              const SliverToBoxAdapter(child: _UpdatePrompt()),
              const SliverToBoxAdapter(child: PendingPaymentBanner()),
              const SliverToBoxAdapter(child: ActiveOrderCard()),
              if (store != null && !store.isOpen)
                SliverToBoxAdapter(child: StoreClosedBanner(store: store)),
              ..._content(context, delivery),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, DeliveryState delivery) {
    final l10n = AppLocalizations.of(context);
    Widget fill(Widget child) =>
        SliverFillRemaining(hasScrollBody: false, child: child);

    if (delivery.location == null) {
      return [
        fill(
          EmptyView(
            message: l10n.homeNeedsLocation,
            icon: Icons.location_on_outlined,
            action: FilledButton(
              onPressed: () => context.push(Routes.location),
              child: Text(l10n.selectLocation),
            ),
          ),
        ),
      ];
    }
    final serviceability = delivery.serviceability;
    if (serviceability == null) {
      final error = delivery.error;
      return [
        if (error != null)
          fill(
            ErrorRetryView(
              error: error,
              onRetry: ref.read(deliveryProvider.notifier).refresh,
            ),
          )
        else
          const SliverFillRemaining(child: HomeSkeleton()),
      ];
    }
    if (!serviceability.serviceable) {
      return [
        fill(
          EmptyView(
            message: l10n.notServiceableInline,
            icon: Icons.wrong_location_outlined,
            action: FilledButton(
              onPressed: () => showAddressSwitcher(context),
              child: Text(l10n.changeLocation),
            ),
          ),
        ),
      ];
    }

    return switch (ref.watch(homeFeedProvider)) {
      AsyncData(:final value) when value.isEmpty => [
        fill(EmptyView(message: l10n.homeEmpty)),
      ],
      AsyncData(:final value) => _sections(context, value),
      // A failed refresh of this store's feed keeps it on screen (CA-03).
      // Another store's feed (a failed reload after a store change) never
      // stays: its prices and stock are not this store's.
      AsyncError(:final value?)
          when delivery.storeId != null &&
              value.store?.id == delivery.storeId =>
        value.isEmpty
            ? [fill(EmptyView(message: l10n.homeEmpty))]
            : _sections(context, value),
      AsyncError(:final error) => [
        fill(
          ErrorRetryView(
            error: error,
            onRetry: () => ref.invalidate(homeFeedProvider),
          ),
        ),
      ],
      _ => [const SliverFillRemaining(child: HomeSkeleton())],
    };
  }

  List<Widget> _sections(BuildContext context, HomeFeed feed) {
    final l10n = AppLocalizations.of(context);
    // Rails come before all products: that grid pages without end, so
    // anything under it would be out of reach.
    return [
      if (feed.banners.isNotEmpty)
        SliverToBoxAdapter(child: BannerCarousel(banners: feed.banners)),
      if (feed.categories.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: HomeSectionHeader(title: l10n.homeCategories),
        ),
        SliverToBoxAdapter(child: HomeCategoryRow(categories: feed.categories)),
      ],
      for (final collection in feed.collections)
        if (collection.items.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: HomeSectionHeader(
              title: collection.name,
              onSeeAll: collection.hasMore
                  ? () => context.push(Routes.collection(collection.slug))
                  : null,
            ),
          ),
          SliverToBoxAdapter(child: HomeProductRail(items: collection.items)),
        ],
      if (feed.buyAgain.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: HomeSectionHeader(
            title: l10n.previouslyBought,
            onSeeAll: () => context.go(Routes.orderAgain),
          ),
        ),
        SliverToBoxAdapter(child: HomeProductRail(items: feed.buyAgain)),
      ],
      SliverToBoxAdapter(
        child: HomeSectionHeader(
          title: l10n.allProducts,
          onSeeAll: () => context.push(Routes.allProducts),
        ),
      ),
      const _AllProducts(),
      const SliverToBoxAdapter(child: SizedBox(height: JivoSpacing.xl)),
    ];
  }
}

/// Every active product of the store as a 2-column grid, so customers need
/// not open a category first. Reuses the category lists' paging and tile.
class _AllProducts extends ConsumerWidget {
  const _AllProducts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = pagedProductsProvider(const AllProductsQuery());
    final storeId = ref.watch(currentStoreIdProvider);
    final state = ref.watch(provider);
    final shown = switch (state) {
      AsyncData(:final value) => value,
      AsyncError(:final value?) when value.storeId == storeId => value,
      _ => null,
    };
    if (shown != null) {
      if (shown.items.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(JivoSpacing.lg),
            child: Center(child: Text(l10n.productsEmpty)),
          ),
        );
      }
      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
            sliver: SliverGrid.builder(
              key: const Key('all-products-grid'),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: productGridMaxExtent(context),
                mainAxisExtent: homeCardExtent(context, shown.items),
                crossAxisSpacing: JivoSpacing.md,
                mainAxisSpacing: JivoSpacing.md,
              ),
              itemCount: shown.items.length,
              itemBuilder: (_, i) => HomeProductCard(product: shown.items[i]),
            ),
          ),
          SliverToBoxAdapter(
            child: LoadMoreFooter(
              state: shown,
              onLoadMore: () => ref.read(provider.notifier).loadMore(),
            ),
          ),
        ],
      );
    }
    if (state is AsyncError) {
      return SliverToBoxAdapter(
        child: ErrorRetryView(
          error: state.error!,
          onRetry: () => ref.invalidate(provider),
        ),
      );
    }
    return const SliverToBoxAdapter(
      child: SizedBox(height: 300, child: ProductGridSkeleton(count: 2)),
    );
  }
}

/// The dismissible "newer version" prompt (Phase 1, `03 §2.1`).
class _UpdatePrompt extends ConsumerWidget {
  const _UpdatePrompt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // LaunchState is a ChangeNotifier behind a plain Provider.
    final launch = ref.watch(launchStateProvider);
    return ListenableBuilder(
      listenable: launch,
      builder: (context, _) {
        if (!launch.showUpdatePrompt) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final storeUrl = launch.config?.storeUrl;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: JivoSpacing.gutter,
            vertical: JivoSpacing.sm,
          ),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(JivoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.updateAvailable),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: launch.dismissUpdatePrompt,
                        child: Text(l10n.later),
                      ),
                      if (storeUrl != null)
                        TextButton(
                          onPressed: () =>
                              ref.read(urlOpenerProvider).open(storeUrl),
                          child: Text(l10n.updateNow),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
