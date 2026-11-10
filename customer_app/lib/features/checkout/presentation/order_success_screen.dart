import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_providers.dart';

/// Order placed (`03 §2.9`, screen #24): animation, order number, ETA and
/// "Track order". Reached only after the server confirmed the order. Back
/// goes Home, never to checkout.
class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({required this.orderId, this.order, super.key});

  final int orderId;

  /// The confirmed order from checkout; loaded by id when absent (e.g. the
  /// route was restored).
  final PlacedOrder? order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final known = order;
    final Widget body;
    if (known != null) {
      body = _Confirmed(order: known);
    } else {
      body = switch (ref.watch(orderProvider(orderId))) {
        AsyncData(:final value) => _Confirmed(order: value),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(orderProvider(orderId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: l10n.close,
              onPressed: () => context.go(Routes.home),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}

class _Confirmed extends StatelessWidget {
  const _Confirmed({required this.order});

  final PlacedOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final success = context.jivoColors.success;
    final eta = order.etaAt;
    final amount = formatRupees(order.grandTotal);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(JivoSpacing.xl),
        child: Column(
          key: const Key('order-success'),
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Icon(Icons.check_circle, size: 96, color: success),
            ),
            const SizedBox(height: JivoSpacing.lg),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                l10n.orderPlacedTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            Text(
              l10n.orderNumber(order.number),
              key: const Key('order-number'),
              style: theme.textTheme.titleMedium,
            ),
            if (eta != null) ...[
              const SizedBox(height: JivoSpacing.xs),
              Text(
                l10n.arrivingBy(formatTime(eta)),
                style: theme.textTheme.bodyLarge,
              ),
            ],
            if (switch (order.paymentMethod) {
                  PaymentMethod.cod => l10n.payOnDeliveryAmount(amount),
                  PaymentMethod.online => l10n.paidOnlineAmount(amount),
                  // A method this build doesn't know: no line, no guess.
                  null => null,
                }
                case final paymentLine?) ...[
              const SizedBox(height: JivoSpacing.xs),
              Text(
                paymentLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: JivoSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('track-order'),
                // The order detail (Phase 4); live tracking opens from
                // there once it is available (Phase 6).
                onPressed: () => context.go(Routes.order(order.id)),
                child: Text(l10n.trackOrder),
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('continue-shopping'),
                onPressed: () => context.go(Routes.home),
                child: Text(l10n.continueShopping),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
