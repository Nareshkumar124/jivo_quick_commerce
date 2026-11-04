import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/state_views.dart';
import '../../addresses/domain/saved_address.dart';
import '../../cart/domain/cart.dart';
import '../../cart/presentation/widgets/bill_details.dart';
import '../domain/order.dart';
import '../domain/order_history.dart';
import 'cancel_order_sheet.dart';
import 'order_history_controllers.dart';
import 'order_texts.dart';
import 'order_timeline.dart';

/// Order detail (`03 §2.10`, screen #26): status and timeline, items, the
/// server's bill, payment and refund status, address, and the actions the
/// server allows: cancel (inside the window, `08 §7`; otherwise "Contact
/// support"), order again, invoice download.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        leading: homeBackButton(context),
        title: Text(switch (detail) {
          AsyncData(:final value) => l10n.orderTitle(value.number),
          _ => l10n.myOrders,
        }),
      ),
      body: switch (detail) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () =>
              ref.read(orderDetailProvider(orderId).notifier).reload(),
          child: _OrderBody(order: value),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        ),
        _ => const SkeletonList(rows: 5),
      },
    );
  }
}

/// Back to Home when the screen was opened with nothing behind it (from
/// the order-placed screen or a deep link); null keeps the normal back.
Widget? homeBackButton(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null || router.canPop()) return null;
  return BackButton(onPressed: () => router.go(Routes.home));
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = buildTimeline(order);
    final running = ref.watch(orderActionsProvider(order.id));
    final canTrack =
        ref.watch(trackingAvailableProvider) &&
        order.isActive &&
        order.status != OrderStatus.paymentPending;
    final eta = order.etaAt;
    final coupon = order.couponCode;

    Widget section(String title, List<Widget> children, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: JivoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: JivoSpacing.sm),
          ...children,
        ],
      ),
    );

    return ListView(
      key: const Key('order-detail'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        // Status.
        Row(
          children: [
            OrderStatusChip(status: order.status),
            const Spacer(),
            Text(
              formatDateTime(order.placedAt ?? order.createdAt),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: JivoSpacing.sm),
        Text(
          orderStatusLabel(l10n, order.status),
          key: const Key('order-status'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (order.isActive && eta != null)
          Text(l10n.orderArrivingBy(formatTime(eta))),
        Text(
          l10n.orderStoreName(order.storeName),
          style: theme.textTheme.bodySmall,
        ),
        if (order.status == OrderStatus.paymentPending) ...[
          const SizedBox(height: JivoSpacing.md),
          Text(l10n.orderAwaitingPayment),
          if (order.canRetryPayment) ...[
            const SizedBox(height: JivoSpacing.sm),
            FilledButton(
              key: const Key('complete-payment'),
              onPressed: () => context.push(Routes.paymentFailed(order.id)),
              child: Text(l10n.completePayment),
            ),
          ],
        ],
        if (canTrack) ...[
          const SizedBox(height: JivoSpacing.md),
          FilledButton.icon(
            key: const Key('track-order'),
            onPressed: () => context.push(Routes.orderTracking(order.id)),
            icon: const Icon(Icons.delivery_dining),
            label: Text(l10n.trackOrder),
          ),
        ],
        if (order.cancellation case final cancellation?
            when cancellation.message.isNotEmpty)
          section(l10n.orderCancelledTitle, [
            Text(cancellation.message, key: const Key('cancellation-message')),
          ]),
        if (steps.isNotEmpty)
          section(l10n.orderTimelineTitle, [OrderTimeline(steps: steps)]),
        const Divider(),

        // Items.
        section(l10n.orderItemsTitle, [
          for (final line in order.lines) _OrderLineRow(line: line),
          Text(
            l10n.orderItemCount(order.itemCount),
            style: theme.textTheme.bodySmall,
          ),
        ]),
        const Divider(),

        // Bill: the server's values, as sent.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: JivoSpacing.md),
          child: BillDetails(
            bill: order.bill,
            coupon: coupon == null
                ? null
                : AppliedCoupon(
                    code: coupon,
                    title: l10n.couponUsed(coupon),
                    discount: order.bill.couponDiscount,
                  ),
          ),
        ),
        const Divider(),

        // Payment and refunds.
        section(l10n.orderPaymentTitle, [
          _PaymentInfo(order: order),
        ], key: const Key('order-payment')),
        const Divider(),

        // Address.
        if (order.address case final address?) ...[
          section(l10n.orderDeliveryTo, [_AddressInfo(address: address)]),
          const Divider(),
        ],

        // Actions.
        const SizedBox(height: JivoSpacing.md),
        if (order.invoiceAvailable)
          _ActionButton(
            buttonKey: const Key('download-invoice'),
            icon: Icons.receipt_long_outlined,
            label: l10n.downloadInvoice,
            busy: running == OrderAction.invoice,
            enabled: running == null,
            onPressed: () => _openInvoice(context, ref),
          ),
        if (order.canReorder)
          _ActionButton(
            buttonKey: const Key('reorder'),
            icon: Icons.replay,
            label: l10n.reorder,
            busy: running == OrderAction.reorder,
            enabled: running == null,
            filled: true,
            onPressed: () => _reorder(context, ref),
          ),
        if (order.canCancel)
          _ActionButton(
            buttonKey: const Key('cancel-order'),
            icon: Icons.close,
            label: l10n.cancelOrder,
            busy: running == OrderAction.cancel,
            enabled: running == null,
            destructive: true,
            onPressed: () => _cancel(context),
          )
        else if (order.needsSupportToCancel)
          _ContactSupportCard(),
        const SizedBox(height: JivoSpacing.xl),
      ],
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cancelled = await showCancelOrderSheet(context, order);
    if (cancelled != null && context.mounted) {
      showMessage(context, l10n.orderCancelled);
    }
  }

  Future<void> _openInvoice(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final opened = await ref
          .read(orderActionsProvider(order.id).notifier)
          .openInvoice();
      if (opened == false && context.mounted) {
        showMessage(context, l10n.invoiceOpenFailed);
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
    }
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ReorderResult? result;
    try {
      result = await ref
          .read(orderActionsProvider(order.id).notifier)
          .reorder();
    } catch (error) {
      if (context.mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
      return;
    }
    if (result == null || !context.mounted) return;
    if (result.addedAll) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.reorderAllAdded),
            action: SnackBarAction(
              label: l10n.viewCart,
              onPressed: () => context.go(Routes.cart),
            ),
          ),
        );
      return;
    }
    final goToCart = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ReorderResultDialog(result: result!, orderLines: order.lines.length),
    );
    if ((goToCart ?? false) && context.mounted) context.go(Routes.cart);
  }
}

/// What a reorder couldn't add (`03 §2.10`: "reports any that are
/// unavailable"). Pops true for "View cart".
class ReorderResultDialog extends StatelessWidget {
  const ReorderResultDialog({
    required this.result,
    required this.orderLines,
    super.key,
  });

  final ReorderResult result;

  /// Lines in the order (to tell "nothing added" from "some added").
  final int orderLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nothing = result.addedNothing(orderLines);
    String line(ReorderSkippedItem item) {
      final name = '${item.productName} (${item.variantName})';
      return switch (item.reason) {
        ReorderSkipReason.quantityReduced => l10n.reorderReduced(
          item.addedQuantity,
          name,
        ),
        ReorderSkipReason.discontinued => l10n.reorderDiscontinued(name),
        _ => l10n.reorderOutOfStock(name),
      };
    }

    return AlertDialog(
      key: const Key('reorder-result'),
      title: Text(
        nothing ? l10n.reorderNothingAdded : l10n.reorderSomeUnavailableTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in result.unavailable)
            Padding(
              padding: const EdgeInsets.only(bottom: JivoSpacing.xs),
              child: Text('• ${line(item)}'),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.close),
        ),
        if (!nothing)
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.viewCart),
          ),
      ],
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  const _OrderLineRow({required this.line});

  final OrderLineItem line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: JivoSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(
              dimension: 48,
              child: ProductImage(url: line.imageUrl),
            ),
            const SizedBox(width: JivoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.productName, style: theme.textTheme.bodyMedium),
                  Text(
                    '${line.variantName} · '
                    '${l10n.orderLineQuantity(line.quantity, formatRupees(line.sellingPrice))}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (line.quantityUnavailable > 0)
                    Text(
                      l10n.orderLineUnavailable(line.quantityUnavailable),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: JivoSpacing.sm),
            Text(
              formatRupees(line.lineTotal),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentInfo extends StatelessWidget {
  const _PaymentInfo({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final method = paymentMethodLabel(l10n, order.paymentMethod);
    final ended =
        order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.paymentFailed;
    final neverPaid =
        ended &&
        (order.paymentStatus == PaymentStatus.pending ||
            order.paymentStatus == PaymentStatus.failed);
    final codNothingDue =
        order.status == OrderStatus.cancelled &&
        order.paymentMethod == PaymentMethod.cod;
    final status = neverPaid || codNothingDue
        ? null
        : paymentStatusLabel(l10n, order.paymentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(method ?? '')),
            if (status != null)
              Text(
                status,
                key: const Key('payment-status'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        if (neverPaid)
          Text(l10n.noPaymentTaken, key: const Key('payment-note'))
        else if (codNothingDue)
          Text(l10n.nothingToPay, key: const Key('payment-note')),
        for (final refund in order.refunds)
          Padding(
            padding: const EdgeInsets.only(top: JivoSpacing.sm),
            child: _RefundLine(refund: refund),
          ),
      ],
    );
  }
}

class _RefundLine extends StatelessWidget {
  const _RefundLine({required this.refund});

  final OrderRefund refund;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final amount = formatRupees(refund.amount);
    final processedAt = refund.processedAt;
    return Container(
      key: const Key('refund-line'),
      padding: const EdgeInsets.all(JivoSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(switch (refund.status) {
            RefundStatus.processed => l10n.refundCompleted(amount),
            RefundStatus.failed => l10n.refundFailedNote(amount),
            _ => l10n.refundInProgress(amount),
          }),
          if (refund.status == RefundStatus.processed && processedAt != null)
            Text(
              l10n.refundedOn(formatDate(processedAt)),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _AddressInfo extends StatelessWidget {
  const _AddressInfo({required this.address});

  final OrderAddressSnapshot address;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label =
        address.customLabel ??
        switch (address.label) {
          AddressLabel.home => l10n.labelHome,
          AddressLabel.work => l10n.labelWork,
          AddressLabel.other => l10n.labelOther,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(address.text, style: theme.textTheme.bodySmall),
        if (address.receiverName.isNotEmpty)
          Text(
            [
              address.receiverName,
              address.receiverPhone,
            ].where((s) => s.isNotEmpty).join(' · '),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _ContactSupportCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final phone = ref.watch(launchStateProvider).config?.supportPhone;
    return Card(
      key: const Key('contact-support'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cannotCancelTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: JivoSpacing.xs),
            Text(l10n.cannotCancelBody),
            if (phone != null) ...[
              const SizedBox(height: JivoSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(urlOpenerProvider)
                    .open(Uri(scheme: 'tel', path: phone)),
                icon: const Icon(Icons.call_outlined),
                label: Text(l10n.contactSupport),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onPressed,
    this.filled = false,
    this.destructive = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final bool busy;
  final bool enabled;
  final bool filled;
  final bool destructive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = busy
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: label,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: JivoSpacing.sm),
              Flexible(child: Text(label)),
            ],
          );
    final action = enabled && !busy ? onPressed : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
      child: SizedBox(
        width: double.infinity,
        child: filled
            ? FilledButton(key: buttonKey, onPressed: action, child: child)
            : OutlinedButton(
                key: buttonKey,
                onPressed: action,
                style: destructive
                    ? OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      )
                    : null,
                child: child,
              ),
      ),
    );
  }
}
