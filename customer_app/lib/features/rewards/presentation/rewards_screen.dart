import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/cart_texts.dart';
import '../../cart/presentation/my_coupons_screen.dart' show MyCouponCard;
import '../../cart/presentation/widgets/coupon_sheet.dart'
    show cartCouponsProvider;
import '../domain/reward.dart';
import 'free_size_sheet.dart';
import 'reward_texts.dart';
import 'rewards_providers.dart';

/// Account > Rewards (was "My coupons", ADR 0002; route kept as
/// `Routes.myCoupons`).
///
/// - **Available:** the free-carton rewards that can be used or are on an
///   order (`GET /account/rewards/` `available`), each with an Available or
///   Claimed chip, then the coupons from `GET /cart/coupons/` (copyable
///   codes). Use applies the reward to the cart and opens the cart: directly
///   when the store has a fixed free size (ADR 0003), else after the size
///   picker.
/// - **History:** earned, claimed, used, expired and volume-offer free
///   cartons, newest first, with dates and order numbers.
///
/// The two lists load on their own: one failing shows its own Retry while
/// the other still shows.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.rewardsTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                key: const Key('rewards-tab-available'),
                text: l10n.rewardsTabAvailable,
              ),
              Tab(
                key: const Key('rewards-tab-history'),
                text: l10n.rewardsTabHistory,
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [_AvailableTab(), _HistoryTab()]),
      ),
    );
  }
}

/// A child that can still be pulled to refresh when it is shorter than the
/// screen (empty and error states).
Widget _scrollable(Widget child) => LayoutBuilder(
  builder: (context, constraints) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: constraints.maxHeight),
      child: child,
    ),
  ),
);

class _AvailableTab extends ConsumerWidget {
  const _AvailableTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rewards = ref.watch(rewardsProvider);
    final coupons = ref.watch(cartCouponsProvider);
    final cartCode = ref.watch(
      cartProvider.select((c) => c.snapshot.coupon?.code),
    );

    void retryRewards() => ref.invalidate(rewardsProvider);
    void retryCoupons() => ref.invalidate(cartCouponsProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(rewardsProvider)
        ..invalidate(cartCouponsProvider);
      await Future.wait([
        refreshQuietly(ref.read(rewardsProvider.future)),
        refreshQuietly(ref.read(cartCouponsProvider.future)),
      ]);
    }

    // Both lists first: no half list that jumps when the other arrives.
    if ((rewards.isLoading && !rewards.hasValue) ||
        (coupons.isLoading && !coupons.hasValue)) {
      return const SkeletonList();
    }
    final rewardsError = rewards.hasValue ? null : rewards.error;
    final couponsError = coupons.hasValue ? null : coupons.error;
    final noStore =
        couponsError != null &&
        ApiError.from(couponsError).code == ApiErrorCode.storeNotFound;

    final Widget body;
    if (rewardsError != null && couponsError != null && !noStore) {
      body = _scrollable(
        ErrorRetryView(
          error: rewardsError,
          onRetry: () {
            retryRewards();
            retryCoupons();
          },
        ),
      );
    } else {
      final split = splitRewardsAndCoupons(
        rewards: rewards.value?.listed ?? const [],
        coupons: coupons.value ?? const [],
      );
      if (split.isEmpty && rewardsError == null && couponsError == null) {
        body = _scrollable(
          EmptyView(
            key: const Key('rewards-empty'),
            message: l10n.rewardsEmpty,
            icon: Icons.card_giftcard_outlined,
          ),
        );
      } else {
        const gap = SizedBox(height: JivoSpacing.md);
        body = ListView(
          key: const Key('rewards-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(JivoSpacing.gutter),
          children: [
            if (rewardsError != null) ...[
              _SectionError(
                key: const Key('rewards-load-failed'),
                error: rewardsError,
                onRetry: retryRewards,
              ),
              gap,
            ],
            if (split.rewards.isNotEmpty) ...[
              _Heading(l10n.rewardsSectionFreeCartons),
              for (final reward in split.rewards) ...[
                RewardCard(
                  reward: reward,
                  inCart:
                      cartCode != null &&
                      cartCode.toUpperCase() == reward.code.toUpperCase(),
                ),
                gap,
              ],
            ],
            if (noStore) ...[
              _NeedsLocation(onChoose: () => context.push(Routes.location)),
              gap,
            ] else if (couponsError != null) ...[
              _SectionError(
                key: const Key('coupons-load-failed'),
                error: couponsError,
                onRetry: retryCoupons,
              ),
              gap,
            ],
            if (split.coupons.isNotEmpty) ...[
              _Heading(l10n.rewardsSectionCoupons),
              for (final offer in split.coupons) ...[
                MyCouponCard(offer: offer),
                gap,
              ],
            ],
          ],
        );
      }
    }
    return RefreshIndicator(onRefresh: refresh, child: body);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// One list failed while the other loaded: its message and Retry.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.md),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
            const SizedBox(width: JivoSpacing.md),
            Expanded(child: Text(describeErrorWithDetails(context, error))),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// No store yet: coupons depend on the store; choose a location.
class _NeedsLocation extends StatelessWidget {
  const _NeedsLocation({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.couponsNeedLocation),
            const SizedBox(height: JivoSpacing.sm),
            FilledButton(
              key: const Key('my-coupons-choose-location'),
              onPressed: onChoose,
              child: Text(l10n.couponsChooseLocation),
            ),
          ],
        ),
      ),
    );
  }
}

/// One reward: "2 free cartons · 1 L × 12" (the server's quantity and
/// fixed size, ADR 0003), where it came from, its expiry, the Available /
/// Claimed chip ("On your order …" when claimed), and Use (or "In your
/// cart" with View cart when it is already on the cart).
///
/// Use: with a fixed free size the reward is applied at once (no size
/// sheet) and the cart opens; its error shows in a snackbar (with Add
/// cartons when more paid cartons are needed). Without one, or when the
/// server still asks for a size, the size sheet picks it.
class RewardCard extends ConsumerStatefulWidget {
  const RewardCard({required this.reward, this.inCart = false, super.key});

  final Reward reward;
  final bool inCart;

  @override
  ConsumerState<RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends ConsumerState<RewardCard> {
  bool _applying = false;

  Reward get reward => widget.reward;

  Future<void> _use() async {
    if (_applying) return;
    if (!reward.hasFixedSize) return _pickSize();
    setState(() => _applying = true);
    try {
      // ADR 0003: no `free_variant_id`; the server uses the store's size.
      await ref.read(cartProvider.notifier).applyCoupon(reward.code);
    } catch (error) {
      if (!mounted) return;
      setState(() => _applying = false);
      // The cart's store has no fixed size after all: pick one.
      if (isFreeSizeRequired(error)) return _pickSize();
      _showError(error);
      return;
    }
    if (!mounted) return;
    setState(() => _applying = false);
    await _openCart();
  }

  Future<void> _pickSize() async {
    final applied = await showFreeSizeSheet(
      context,
      code: reward.code,
      quantity: reward.quantity,
    );
    if (!applied || !mounted) return;
    await _openCart();
  }

  Future<void> _openCart() async {
    final l10n = AppLocalizations.of(context);
    final quantity =
        ref.read(cartProvider).snapshot.coupon?.freeQuantity ?? reward.quantity;
    showMessage(context, l10n.freeCartonsAdded(quantity));
    // Pushed (on the root navigator, like the cart bar does): Back
    // returns to Rewards.
    await context.push(Routes.cart);
  }

  void _showError(Object error) {
    final l10n = AppLocalizations.of(context);
    final needsCartons =
        ApiError.from(error).details['reason'] == 'MIN_ORDER_UNITS';
    final text = cartErrorText(
      context,
      error,
      cart: ref.read(cartProvider).snapshot,
      fixedFreeSize: true,
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: ValueKey('reward-error-${reward.code}'),
          content: Text(text),
          action: needsCartons
              ? SnackBarAction(
                  label: l10n.rewardAddCartons,
                  onPressed: () => context.push(Routes.allProducts),
                )
              : null,
        ),
      );
  }

  /// "2 free cartons · 1 L × 12", "2 free cartons" without a named size,
  /// or the server's title for a reward that is not a free carton.
  String _title(AppLocalizations l10n) {
    if (!reward.isFreeCarton) return reward.title;
    final size = reward.freeVariant?.name.trim();
    return size == null || size.isEmpty
        ? l10n.freeCartonCount(reward.quantity)
        : l10n.freeCartonsOfSize(reward.quantity, size);
  }

  @override
  Widget build(BuildContext context) {
    final inCart = widget.inCart;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final source = rewardSourceText(l10n, reward.source);
    final expiresAt = reward.expiresAt;
    final order = reward.orderNumber;
    final claimed = reward.status == RewardStatus.claimed;
    final code = reward.code;

    return Card(
      key: ValueKey('reward-$code'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.card_giftcard,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: JivoSpacing.md),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title(l10n),
                          key: ValueKey('reward-title-$code'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (source != null)
                          Text(
                            source,
                            key: ValueKey('reward-source-$code'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        if (expiresAt != null && !claimed)
                          Text(
                            l10n.couponExpiresOn(formatDate(expiresAt)),
                            key: ValueKey('reward-expiry-$code'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        if (claimed && order != null)
                          Text(
                            l10n.rewardOnOrder(order),
                            key: ValueKey('reward-order-$code'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: JivoSpacing.sm),
                _StatusChip(status: reward.status, code: code),
              ],
            ),
            if (reward.isFreeCarton && reward.canUse) ...[
              const SizedBox(height: JivoSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: inCart
                    ? Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: JivoSpacing.sm,
                        children: [
                          Text(
                            l10n.rewardInCart,
                            key: ValueKey('reward-in-cart-$code'),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: context.jivoColors.success,
                            ),
                          ),
                          OutlinedButton(
                            key: ValueKey('reward-view-cart-$code'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                kJivoMinTouchTarget,
                                kJivoMinTouchTarget,
                              ),
                            ),
                            onPressed: () => context.push(Routes.cart),
                            child: Text(l10n.rewardViewCart),
                          ),
                        ],
                      )
                    : FilledButton(
                        key: ValueKey('reward-use-$code'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, kJivoMinTouchTarget),
                        ),
                        onPressed: _applying ? null : _use,
                        child: _applying
                            ? SizedBox.square(
                                key: ValueKey('reward-applying-$code'),
                                dimension: 20,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                l10n.rewardUse,
                                semanticsLabel: l10n.rewardUseSemantics(
                                  reward.quantity,
                                ),
                              ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Available" (green) or "Claimed" (amber); text, not only colour.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.code});

  final RewardStatus status;
  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.jivoColors;
    final color = status == RewardStatus.claimed
        ? colors.warning
        : colors.success;
    return DecoratedBox(
      key: ValueKey('reward-status-$code'),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: JivoSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          rewardStatusText(l10n, status),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rewards = ref.watch(rewardsProvider);

    Future<void> refresh() async {
      ref.invalidate(rewardsProvider);
      await refreshQuietly(ref.read(rewardsProvider.future));
    }

    final Widget body = switch (rewards) {
      AsyncData(:final value) when value.history.isEmpty => _scrollable(
        EmptyView(
          key: const Key('rewards-history-empty'),
          message: l10n.rewardsHistoryEmpty,
          icon: Icons.history,
        ),
      ),
      AsyncData(:final value) => ListView.separated(
        key: const Key('rewards-history'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(JivoSpacing.gutter),
        itemCount: value.timeline.length,
        separatorBuilder: (_, _) => const Divider(height: JivoSpacing.lg),
        itemBuilder: (context, index) => _HistoryRow(
          key: ValueKey('reward-history-$index'),
          entry: value.timeline[index],
        ),
      ),
      AsyncError(:final error) => _scrollable(
        ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(rewardsProvider),
        ),
      ),
      _ => const SkeletonList(),
    };
    return RefreshIndicator(onRefresh: refresh, child: body);
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, super.key});

  final RewardHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final kind = rewardHistoryKindText(l10n, entry.kind);
    final order = entry.orderNumber;
    final headline = [?kind, l10n.freeCartonCount(entry.quantity)].join(' · ');
    final details = [
      formatDate(entry.at),
      if (order != null) l10n.rewardHistoryOrder(order),
    ].join(' · ');
    final icon = switch (entry.kind) {
      RewardHistoryKind.earned => Icons.card_giftcard,
      RewardHistoryKind.claimed => Icons.shopping_bag_outlined,
      RewardHistoryKind.used => Icons.check_circle_outline,
      RewardHistoryKind.expired => Icons.timer_off_outlined,
      RewardHistoryKind.volumeFree => Icons.local_offer_outlined,
      RewardHistoryKind.unknown => Icons.history,
    };
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: theme.colorScheme.primary)),
          const SizedBox(width: JivoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (entry.title.trim().isNotEmpty)
                  Text(entry.title, style: theme.textTheme.bodyMedium),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
