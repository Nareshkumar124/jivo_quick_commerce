import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../catalog/presentation/widgets/paged_product_grid.dart';
import '../../catalog/presentation/widgets/product_tile.dart';
import '../../location/domain/delivery_location.dart';
import '../../location/presentation/delivery_controller.dart';
import '../../location/presentation/location_options.dart';
import '../../location/presentation/store_closed_banner.dart';
import '../../orders/presentation/active_order_card.dart';
import '../../orders/presentation/pending_payment.dart';
import 'banner_carousel.dart';

/// Home (`03 §2.5`): ETA and address header, search bar, banners, category
/// grid, collection rails and "Previously bought". Pull to refresh reloads
/// home and re-checks serviceability.
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
      // No top SafeArea: the green header paints behind the status bar and
      // adds the top inset itself.
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _HomeHeader(
                  delivery: delivery,
                  searchHint: l10n.searchHint,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: JivoSpacing.md)),
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
    return [
      if (feed.banners.isNotEmpty)
        SliverToBoxAdapter(child: BannerCarousel(banners: feed.banners)),
      SliverToBoxAdapter(child: _SectionHeader(title: l10n.allProducts)),
      const _AllProducts(),
      for (final collection in feed.collections)
        if (collection.items.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: collection.name,
              onSeeAll: collection.hasMore
                  ? () => context.push(Routes.collection(collection.slug))
                  : null,
            ),
          ),
          SliverToBoxAdapter(child: ProductRail(items: collection.items)),
        ],
      if (feed.buyAgain.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: l10n.previouslyBought,
            onSeeAll: () => context.go(Routes.orderAgain),
          ),
        ),
        SliverToBoxAdapter(child: ProductRail(items: feed.buyAgain)),
      ],
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
                mainAxisExtent: productTileExtent(
                  context,
                  minQtyHint: needsMinQtyHint(shown.items),
                ),
                crossAxisSpacing: JivoSpacing.md,
                mainAxisSpacing: JivoSpacing.md,
              ),
              itemCount: shown.items.length,
              itemBuilder: (_, i) => ProductTile(product: shown.items[i]),
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
      child: SizedBox(height: 280, child: ProductGridSkeleton()),
    );
  }
}

/// The deep-green header band: ETA, address, account button and the search
/// bar. It grows with the text and extends under the status bar.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.delivery, required this.searchHint});

  final DeliveryState delivery;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cc = context.customerColors;
    final location = delivery.location;
    final serviceability = delivery.serviceability;
    final eta = serviceability?.etaMinutes;
    final headline = switch ((location, serviceability)) {
      (null, _) => l10n.selectLocation,
      (_, null) => l10n.checkingDelivery,
      (_, Serviceability(serviceable: false)) => l10n.notDeliveringHere,
      _ when eta != null => l10n.deliveryIn(eta),
      (_, Serviceability(storeClosed: true)) => l10n.storeClosedHeadline,
      _ => l10n.appTitle,
    };
    final address = location == null
        ? null
        : [location.title, ?location.subtitle].join(' · ');
    final showsEta = location != null && serviceability != null && eta != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: DecoratedBox(
        key: const Key('home-header'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cc.headerGradient,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(JivoRadii.xl),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            JivoSpacing.gutter,
            MediaQuery.paddingOf(context).top + 8,
            JivoSpacing.gutter,
            JivoSpacing.gutter,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      hint: l10n.changeLocationSemantics,
                      child: InkWell(
                        key: const Key('home-address'),
                        borderRadius: BorderRadius.circular(JivoRadii.sm),
                        splashColor: Colors.white24,
                        onTap: () => location == null
                            ? context.push(Routes.location)
                            : showAddressSwitcher(context),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: kJivoMinTouchTarget,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ExcludeSemantics(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        right: 6,
                                      ),
                                      child: Icon(
                                        showsEta
                                            ? Icons.bolt_rounded
                                            : Icons.location_on_rounded,
                                        size: 22,
                                        color: cc.gold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      headline,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              if (address != null)
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.accountTitle,
                    iconSize: 28,
                    color: Colors.white,
                    icon: const Icon(Icons.account_circle_rounded),
                    onPressed: () => context.go(Routes.account),
                  ),
                ],
              ),
              const SizedBox(height: JivoSpacing.lg),
              _SearchBar(hint: searchHint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Looks like a search field; opens the search screen.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: context.customerColors.shadow,
        borderRadius: BorderRadius.circular(JivoRadii.lg),
        child: InkWell(
          key: const Key('home-search'),
          borderRadius: BorderRadius.circular(JivoRadii.lg),
          onTap: () => context.push(Routes.search),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JivoSpacing.md,
                vertical: JivoSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: JivoSpacing.sm),
                  Expanded(
                    child: Text(
                      hint,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      JivoSpacing.gutter,
      JivoSpacing.lg,
      JivoSpacing.xs,
      JivoSpacing.xs,
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(AppLocalizations.of(context).seeAll),
          ),
      ],
    ),
  );
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
