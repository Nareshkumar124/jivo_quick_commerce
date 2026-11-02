import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/state_views.dart';
import '../../catalog/presentation/catalog_controllers.dart';
import '../../catalog/presentation/widgets/product_tile.dart';
import '../../location/presentation/delivery_controller.dart';

/// The "Order again" tab: previously bought items as a grid, from the home
/// feed's buy-again list (`03 §2.5`).
class OrderAgainScreen extends ConsumerWidget {
  const OrderAgainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final storeId = ref.watch(currentStoreIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabOrderAgain)),
      body: storeId == null
          ? EmptyView(
              message: l10n.homeNeedsLocation,
              icon: Icons.location_on_outlined,
              action: FilledButton(
                onPressed: () => context.push(Routes.location),
                child: Text(l10n.selectLocation),
              ),
            )
          : switch (ref.watch(homeFeedProvider)) {
              AsyncData(:final value) when value.buyAgain.isEmpty => EmptyView(
                message: l10n.orderAgainEmpty,
                icon: Icons.replay,
              ),
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () => ref.refresh(homeFeedProvider.future),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(JivoSpacing.sm),
                      sliver: SliverProductGrid(items: value.buyAgain),
                    ),
                  ],
                ),
              ),
              AsyncError(:final error) => ErrorRetryView(
                error: error,
                onRetry: () => ref.invalidate(homeFeedProvider),
              ),
              _ => const ProductGridSkeleton(),
            },
    );
  }
}
