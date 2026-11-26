import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../tracking/presentation/order_live.dart';
import '../domain/order.dart';
import 'order_texts.dart';
import 'pending_payment.dart';

/// The customer's orders still in progress and not waiting for payment,
/// newest first, for the Home card (CA-10,
/// `design/screens/customer/home-active-order-card.md`). Filled by
/// [PendingPaymentController.check] from the same
/// `GET /orders/?status=active` answer, so Home makes one request for both.
class ActiveOrders extends Notifier<List<PlacedOrder>> {
  @override
  List<PlacedOrder> build() => const [];

  void set(List<PlacedOrder> orders) => state = List.unmodifiable([
    for (final order in orders)
      if (order.status.isActive && order.status != OrderStatus.paymentPending)
        order,
  ]);
}

final activeOrdersProvider = NotifierProvider<ActiveOrders, List<PlacedOrder>>(
  ActiveOrders.new,
);

/// Home: the newest order in progress as one button ("On the way ·
/// Arriving by 3:45 pm · Delivery OTP ready · Track ›"), and "+1 more
/// order in progress · See all" when there are more. A status message on
/// the shown order's socket re-reads the list. Never shows money or the
/// delivery OTP itself.
class ActiveOrderCard extends ConsumerWidget {
  const ActiveOrderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(activeOrdersProvider);
    if (orders.isEmpty) return const SizedBox.shrink();
    final order = orders.first;
    // The socket shared with My orders, the detail and tracking.
    ref.listen(orderStatusEventsProvider(order.id), (_, next) {
      if (next.hasValue) ref.read(pendingPaymentProvider.notifier).check();
    });
    final more = orders.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        JivoSpacing.gutter,
        0,
        JivoSpacing.gutter,
        JivoSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrderCard(order: order),
          if (more > 0) _MoreOrders(count: more),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = order.status;
    final failed = status == OrderStatus.deliveryFailed;
    final known = status != OrderStatus.unknown;
    final tracks = !failed && known && ref.watch(trackingAvailableProvider);
    final (background, foreground) = failed
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : known
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : (scheme.surfaceContainerHighest, scheme.onSurface);
    final icon = switch (status) {
      OrderStatus.placed => Icons.receipt_long,
      OrderStatus.accepted => Icons.thumb_up_alt_outlined,
      OrderStatus.packing => Icons.inventory_2_outlined,
      OrderStatus.packed => Icons.inventory,
      OrderStatus.outForDelivery => Icons.delivery_dining,
      OrderStatus.deliveryFailed => Icons.error_outline,
      _ => Icons.info_outline,
    };
    final title = known
        ? orderStatusLabel(l10n, status)
        : l10n.orderStatusUnknown;
    final eta = order.etaAt;
    final detail = failed
        ? l10n.activeOrderDeliveryFailedBody
        : eta != null && known
        ? l10n.orderArrivingBy(formatTime(eta))
        : l10n.orderNumber(order.number);
    final otpReady = status == OrderStatus.outForDelivery;
    final action = tracks ? l10n.activeOrderTrack : l10n.activeOrderDetails;
    // From 1.5× text the trailing label moves under the lines (spec §8).
    final large = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.5;

    void open() => context.push(
      tracks ? Routes.orderTracking(order.id) : Routes.order(order.id),
    );

    final trailing = Text(
      '$action ›',
      style: theme.textTheme.labelLarge?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
    );
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: large ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          detail,
          style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
        ),
        if (otpReady)
          Row(
            key: const Key('active-order-otp-ready'),
            children: [
              Icon(Icons.pin_outlined, size: 16, color: foreground),
              const SizedBox(width: JivoSpacing.xs),
              Flexible(
                child: Text(
                  l10n.activeOrderOtpReady,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        if (large) ...[const SizedBox(height: JivoSpacing.xs), trailing],
      ],
    );

    return Semantics(
      button: true,
      label: l10n.activeOrderSemantics(
        [title, detail, if (otpReady) l10n.activeOrderOtpReady].join('. '),
        tracks ? l10n.activeOrderOpensTracking : l10n.activeOrderOpensDetails,
      ),
      // The content's own semantics (and the InkWell's) are excluded, so the
      // tap action is declared here.
      onTap: open,
      excludeSemantics: true,
      child: Material(
        key: const Key('active-order-card'),
        color: background,
        borderRadius: BorderRadius.circular(JivoRadii.md),
        child: InkWell(
          key: const Key('active-order-track'),
          borderRadius: BorderRadius.circular(JivoRadii.md),
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JivoSpacing.lg,
                vertical: JivoSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 28, color: foreground),
                  const SizedBox(width: JivoSpacing.md),
                  Expanded(child: lines),
                  if (!large) ...[
                    const SizedBox(width: JivoSpacing.sm),
                    trailing,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "+1 more order in progress · See all", one 48 dp button to My orders.
class _MoreOrders extends StatelessWidget {
  const _MoreOrders({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InkWell(
      key: const Key('active-orders-more'),
      // Pushed over Home, so back returns to Home as it was.
      onTap: () => context.push(Routes.orders),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kJivoMinTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JivoSpacing.xs),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.activeOrderMore(count),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: l10n.activeOrderSeeAll,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }
}
