import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/order.dart';

/// The order still waiting for payment, if any (`03 §2.9` edge case: the app
/// was killed mid-payment). Home asks on start and on refresh
/// (`GET /orders/?status=active`); the payment screen then shows the
/// server's status, webhook-confirmed or not.
class PendingPaymentController extends Notifier<PlacedOrder?> {
  final _autoOpened = <int>{};

  @override
  PlacedOrder? build() => null;

  /// Looks for a `PAYMENT_PENDING` order. A failure keeps the last answer:
  /// this is a convenience, never a gate.
  Future<void> check() async {
    if (!ref.read(cartAvailableProvider)) return;
    try {
      final orders = await ref.read(orderRepositoryProvider).activeOrders();
      if (!ref.mounted) return;
      state = orders
          .where((order) => order.status == OrderStatus.paymentPending)
          .firstOrNull;
    } catch (_) {
      // Keep the last answer.
    }
  }

  /// True once per order per app session: the payment screen opens by
  /// itself the first time a pending order is found, after that only from
  /// the banner.
  bool takeAutoOpen(int orderId) => _autoOpened.add(orderId);
}

final pendingPaymentProvider =
    NotifierProvider<PendingPaymentController, PlacedOrder?>(
      PendingPaymentController.new,
    );

/// Re-checks after an order changed state (paid, cancelled, left unpaid).
void refreshPendingPayment(Ref ref) =>
    ref.read(pendingPaymentProvider.notifier).check();

/// Home: "Order X is waiting for payment · Pay now". Also opens the
/// payment screen once, the first time a pending order is found.
class PendingPaymentBanner extends ConsumerStatefulWidget {
  const PendingPaymentBanner({super.key});

  @override
  ConsumerState<PendingPaymentBanner> createState() =>
      _PendingPaymentBannerState();
}

class _PendingPaymentBannerState extends ConsumerState<PendingPaymentBanner> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(pendingPaymentProvider.notifier).check();
    });
  }

  void _open(PlacedOrder order) => context.push(Routes.paymentFailed(order.id));

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingPaymentProvider, (previous, next) {
      if (next != null &&
          previous?.id != next.id &&
          ref.read(pendingPaymentProvider.notifier).takeAutoOpen(next.id)) {
        _open(next);
      }
    });
    final order = ref.watch(pendingPaymentProvider);
    if (order == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        JivoSpacing.gutter,
        0,
        JivoSpacing.gutter,
        JivoSpacing.md,
      ),
      child: Material(
        key: const Key('pending-payment-banner'),
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(JivoRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(JivoRadii.md),
          onTap: () => _open(order),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kJivoMinTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JivoSpacing.lg,
                vertical: JivoSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: scheme.onErrorContainer),
                  const SizedBox(width: JivoSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.pendingPaymentBanner(order.number),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                  Text(
                    l10n.pendingPaymentAction,
                    style: TextStyle(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
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
