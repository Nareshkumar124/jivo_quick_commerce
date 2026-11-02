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
import '../../catalog/presentation/categories_screen.dart';
import '../../catalog/presentation/widgets/product_tile.dart';
import '../../location/domain/delivery_location.dart';
import '../../location/presentation/delivery_controller.dart';
import '../../location/presentation/location_options.dart';
import '../../location/presentation/store_closed_banner.dart';
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
    // The feed carries the store's live status; until it loads, the
    // serviceability check's.
    final store = delivery.store == null
        ? null
        : ref.watch(homeFeedProvider).value?.store ?? delivery.store;
    return Scaffold(
      key: const Key('home-screen'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _HomeHeader(delivery: delivery)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    JivoSpacing.gutter,
                    JivoSpacing.xs,
                    JivoSpacing.gutter,
                    JivoSpacing.md,
                  ),
                  child: _SearchBar(hint: l10n.searchHint),
                ),
              ),
              const SliverToBoxAdapter(child: _UpdatePrompt()),
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
      if (feed.categories.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(title: l10n.shopByCategory)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.gutter),
          sliver: SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 96,
              mainAxisExtent: categoryTileExtent(context),
              crossAxisSpacing: JivoSpacing.sm,
              mainAxisSpacing: JivoSpacing.sm,
            ),
            itemCount: feed.categories.length,
            itemBuilder: (context, i) {
              final category = feed.categories[i];
              return CategoryTile(
                key: ValueKey('home-category-${category.slug}'),
                label: category.name,
                imageUrl: category.imageUrl,
                onTap: () => context.push(Routes.category(category.slug)),
              );
            },
          ),
        ),
      ],
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.delivery});

  final DeliveryState delivery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        JivoSpacing.gutter,
        JivoSpacing.sm,
        JivoSpacing.xs,
        JivoSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              hint: l10n.changeLocationSemantics,
              child: InkWell(
                key: const Key('home-address'),
                borderRadius: BorderRadius.circular(JivoRadii.sm),
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
                      Text(
                        headline,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (address != null)
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
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
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.go(Routes.account),
          ),
        ],
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
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(JivoRadii.md),
        child: InkWell(
          key: const Key('home-search'),
          borderRadius: BorderRadius.circular(JivoRadii.md),
          onTap: () => context.push(Routes.search),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kJivoMinTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JivoSpacing.md,
                vertical: JivoSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
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
