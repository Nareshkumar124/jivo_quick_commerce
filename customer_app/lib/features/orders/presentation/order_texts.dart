import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/order.dart';
import '../domain/order_history.dart';

/// The customer-facing label of each order status (`08 §1`).
String orderStatusLabel(AppLocalizations l10n, OrderStatus status) =>
    switch (status) {
      OrderStatus.paymentPending => l10n.orderStatusPaymentPending,
      OrderStatus.placed => l10n.orderStatusPlaced,
      OrderStatus.accepted => l10n.orderStatusAccepted,
      OrderStatus.packing => l10n.orderStatusPacking,
      OrderStatus.packed => l10n.orderStatusPacked,
      OrderStatus.outForDelivery => l10n.orderStatusOutForDelivery,
      OrderStatus.delivered => l10n.orderStatusDelivered,
      OrderStatus.cancelled => l10n.orderStatusCancelled,
      OrderStatus.paymentFailed => l10n.orderStatusPaymentFailed,
      OrderStatus.deliveryFailed ||
      OrderStatus.returned => l10n.orderStatusDeliveryFailed,
      OrderStatus.unknown => l10n.orderStatusUnknown,
    };

String orderStageLabel(AppLocalizations l10n, OrderStage stage) =>
    switch (stage) {
      OrderStage.placed => l10n.orderStagePlaced,
      OrderStage.confirmed => l10n.orderStageConfirmed,
      OrderStage.packing => l10n.orderStagePacking,
      OrderStage.onTheWay => l10n.orderStageOnTheWay,
      OrderStage.delivered => l10n.orderStageDelivered,
    };

/// The payment-status line, or null when it says nothing useful.
String? paymentStatusLabel(AppLocalizations l10n, PaymentStatus status) =>
    switch (status) {
      PaymentStatus.pending => l10n.paymentStatusPending,
      PaymentStatus.paid => l10n.paymentStatusPaid,
      PaymentStatus.failed => l10n.paymentStatusFailed,
      PaymentStatus.refundPending => l10n.paymentStatusRefundPending,
      PaymentStatus.refunded => l10n.paymentStatusRefunded,
      PaymentStatus.partiallyRefunded => l10n.paymentStatusPartiallyRefunded,
      PaymentStatus.codPending => l10n.paymentStatusCodPending,
      PaymentStatus.codCollected => l10n.paymentStatusCodCollected,
      PaymentStatus.unknown => null,
    };

String? paymentMethodLabel(AppLocalizations l10n, PaymentMethod? method) =>
    switch (method) {
      PaymentMethod.online => l10n.paymentMethodOnline,
      PaymentMethod.cod => l10n.paymentMethodCod,
      null => null,
    };

String cancelReasonLabel(AppLocalizations l10n, CancelReason reason) =>
    switch (reason) {
      CancelReason.orderedByMistake => l10n.cancelReasonOrderedByMistake,
      CancelReason.changedMind => l10n.cancelReasonChangedMind,
      CancelReason.deliveryTooSlow => l10n.cancelReasonDeliveryTooSlow,
      CancelReason.changePaymentMethod => l10n.cancelReasonChangePaymentMethod,
      CancelReason.paymentProblem => l10n.cancelReasonPaymentProblem,
      CancelReason.other => l10n.cancelReasonOther,
    };

/// The chip colours of a status: in progress, delivered, or ended badly.
({Color background, Color foreground}) statusColors(
  BuildContext context,
  OrderStatus status,
) {
  final scheme = Theme.of(context).colorScheme;
  final success = context.jivoColors.success;
  return switch (status) {
    OrderStatus.delivered => (
      background: success.withValues(alpha: 0.12),
      foreground: success,
    ),
    OrderStatus.cancelled ||
    OrderStatus.paymentFailed ||
    OrderStatus.deliveryFailed ||
    OrderStatus.returned => (
      background: scheme.errorContainer,
      foreground: scheme.onErrorContainer,
    ),
    OrderStatus.unknown => (
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurfaceVariant,
    ),
    _ => (
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
    ),
  };
}

/// A status chip ("On the way", "Delivered", …).
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, super.key});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = statusColors(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JivoSpacing.sm,
        vertical: JivoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Text(
        orderStatusLabel(AppLocalizations.of(context), status),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: colors.foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
