import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/order_history.dart';
import 'order_history_controllers.dart';
import 'order_texts.dart';

/// "My orders" (`03 §2.10`, screen #25): active orders on top, then past
/// orders, with infinite scroll and pull to refresh.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.myOrders)),
      body: switch (ref.watch(orderListProvider)) {
        AsyncData(:final value) when value.items.isEmpty => EmptyView(
          key: const Key('orders-empty'),
          message: l10n.ordersEmpty,
          icon: Icons.receipt_long_outlined,
          action: FilledButton(
            onPressed: () => context.go(Routes.home),
            child: Text(l10n.startShopping),
          ),
        ),
        AsyncData(:final value) => _OrderList(state: value),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(orderListProvider),
        ),
        _ => const SkeletonList(rows: 5),
      },
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.state});

  final OrderListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(orderListProvider.notifier);
    final active = state.active;
    final past = state.past;
    final rows = <Widget>[
      if (active.isNotEmpty) ...[
        _SectionTitle(l10n.ordersActive),
        for (final order in active) OrderListTile(order: order),
      ],
      if (past.isNotEmpty) ...[
        _SectionTitle(l10n.ordersPast),
        for (final order in past) OrderListTile(order: order),
      ],
      if (state.loadingMore)
        const Padding(
          padding: EdgeInsets.all(JivoSpacing.lg),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (state.loadMoreError != null)
        Padding(
          padding: const EdgeInsets.all(JivoSpacing.lg),
          child: Column(
            children: [
              Text(l10n.ordersLoadMoreFailed),
              TextButton(
                onPressed: controller.loadMore,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
    ];
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400 &&
              state.hasMore &&
              state.loadMoreError == null) {
            controller.loadMore();
          }
          return false;
        },
        child: ListView(
          key: const Key('orders-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: JivoSpacing.xl),
          children: rows,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      JivoSpacing.gutter,
      JivoSpacing.lg,
      JivoSpacing.gutter,
      JivoSpacing.sm,
    ),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// One order in the list: thumbnails, status chip, number, date, units and
/// the server's total. Opens the order detail.
class OrderListTile extends StatelessWidget {
  const OrderListTile({required this.order, super.key});

  final OrderListItem order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      key: Key('order-${order.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: JivoSpacing.gutter,
        vertical: JivoSpacing.xs,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.order(order.id)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kJivoMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.all(JivoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: OrderStatusChip(status: order.status),
                      ),
                    ),
                    Text(
                      formatRupees(order.grandTotal),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: JivoSpacing.sm),
                if (order.imageUrls.isNotEmpty) ...[
                  ExcludeSemantics(
                    child: Row(
                      children: [
                        for (final url in order.imageUrls.take(4))
                          Padding(
                            padding: const EdgeInsets.only(
                              right: JivoSpacing.xs,
                            ),
                            child: SizedBox.square(
                              dimension: 40,
                              child: ProductImage(url: url),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: JivoSpacing.sm),
                ],
                Text(
                  l10n.orderNumber(order.number),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  [
                    l10n.orderPlacedOn(
                      formatDateTime(order.placedAt ?? order.createdAt),
                    ),
                    l10n.orderItemCount(order.itemCount),
                  ].join(' · '),
                  style: muted,
                ),
                if (order.isActive && order.etaAt != null)
                  Text(
                    l10n.orderArrivingBy(formatTime(order.etaAt!)),
                    style: muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
