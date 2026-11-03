import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../orders/domain/order.dart';
import '../data/payment_launcher.dart';
import 'payment_retry_controller.dart';

/// What checkout knew when the payment didn't complete.
class PaymentFailedArgs {
  const PaymentFailedArgs({required this.order, this.reason, this.error});

  final PlacedOrder order;
  final PaymentFailureReason? reason;
  final Object? error;
}

/// Payment failed / retry (`03 §2.9`, screen #23).
///
/// It shows the server's status first: if the webhook confirmed the payment
/// meanwhile, it moves on to the success screen. A `PAYMENT_PENDING` order
/// offers Retry (until the payment window ends), Change payment method and
/// Cancel order (T5). Back goes Home; the unpaid order stays until it
/// expires.
class PaymentFailedScreen extends ConsumerStatefulWidget {
  const PaymentFailedScreen({required this.orderId, this.args, super.key});

  final int orderId;
  final PaymentFailedArgs? args;

  @override
  ConsumerState<PaymentFailedScreen> createState() =>
      _PaymentFailedScreenState();
}

class _PaymentFailedScreenState extends ConsumerState<PaymentFailedScreen> {
  Future<void> _confirmCancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelOrderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.keepOrder),
          ),
          TextButton(
            key: const Key('confirm-cancel-order'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cancelOrder),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(paymentRetryProvider(widget.orderId).notifier).cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = paymentRetryProvider(widget.orderId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      final confirmed = next.confirmed;
      if (confirmed != null && previous?.confirmed == null) {
        context.go(Routes.orderSuccess(confirmed.id), extra: confirmed);
        return;
      }
      final after = next.afterCancel;
      if (after != null && previous?.afterCancel == null) {
        showMessage(context, l10n.orderCancelled);
        context.go(switch (after) {
          AfterCancel.cart => Routes.cart,
          AfterCancel.checkout => Routes.checkout,
        });
      }
    });

    // Until the server answers, show what checkout knew; until a retry,
    // show why checkout's attempt failed.
    final args = widget.args;
    final order = state.order ?? args?.order;
    final reason = state.retried ? state.reason : args?.reason;
    final error = state.error ?? (state.retried ? null : args?.error);
    final Widget body;
    if (order == null) {
      final loadError = state.loadError;
      body = loadError != null && !state.loading
          ? ErrorRetryView(error: loadError, onRetry: controller.reload)
          : const Center(child: CircularProgressIndicator());
    } else {
      body = _Body(
        order: order,
        state: state,
        reason: reason,
        error: error,
        onRetry: controller.retry,
        onChangeMethod: () => controller.cancel(changeMethod: true),
        onCancel: _confirmCancel,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !state.busy) context.go(Routes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.paymentFailedTitle),
          actions: [
            IconButton(
              tooltip: l10n.close,
              onPressed: state.busy ? null : () => context.go(Routes.home),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: body,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.order,
    required this.state,
    required this.reason,
    required this.error,
    required this.onRetry,
    required this.onChangeMethod,
    required this.onCancel,
  });

  final PlacedOrder order;
  final PaymentRetryState state;
  final PaymentFailureReason? reason;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onChangeMethod;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final expiresAt = order.paymentExpiresAt;
    final windowOpen =
        expiresAt == null || DateTime.now().toUtc().isBefore(expiresAt);
    final pending = order.status == OrderStatus.paymentPending;
    final disabled = state.busy || state.loading;
    final error = this.error;

    final String headline;
    final List<String> details;
    switch (order.status) {
      case OrderStatus.paymentFailed:
        headline = l10n.paymentFailedTitle;
        details = [l10n.paymentWindowOver(order.number)];
      case OrderStatus.cancelled:
        headline = l10n.orderCancelled;
        details = [l10n.paymentOrderCancelled(order.number)];
      default:
        headline = l10n.paymentFailedTitle;
        details = [
          l10n.paymentNotCompleted(order.number),
          if (error != null)
            describeErrorWithDetails(context, error)
          else if (reason == PaymentFailureReason.cancelled)
            l10n.paymentCancelled,
          if (pending && expiresAt != null && windowOpen)
            l10n.paymentPayBy(formatTime(expiresAt)),
        ];
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(JivoSpacing.xl),
        child: Column(
          key: const Key('payment-failed'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: theme.colorScheme.error),
            const SizedBox(height: JivoSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            for (final text in details)
              Padding(
                padding: const EdgeInsets.only(bottom: JivoSpacing.xs),
                child: Text(text, textAlign: TextAlign.center),
              ),
            const SizedBox(height: JivoSpacing.xl),
            if (pending) ...[
              BusyButton(
                key: const Key('retry-payment'),
                label: l10n.retryPayment,
                busy: state.action == RetryAction.retrying,
                onPressed: disabled || !windowOpen ? null : onRetry,
              ),
              const SizedBox(height: JivoSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('change-payment-method'),
                  onPressed: disabled ? null : onChangeMethod,
                  child: Text(l10n.changePaymentMethod),
                ),
              ),
              const SizedBox(height: JivoSpacing.sm),
              TextButton(
                key: const Key('cancel-order'),
                onPressed: disabled ? null : onCancel,
                child: Text(l10n.cancelOrder),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('back-to-cart'),
                  onPressed: () => context.go(Routes.cart),
                  child: Text(l10n.backToCart),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
