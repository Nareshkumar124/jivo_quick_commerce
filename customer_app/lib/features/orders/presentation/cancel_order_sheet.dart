import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/order.dart';
import '../domain/order_history.dart';
import 'order_history_controllers.dart';
import 'order_texts.dart';

/// Opens the cancel sheet (`03 §2.10`, screen #27). Resolves to the
/// cancelled order, or null when the customer kept it.
Future<OrderDetail?> showCancelOrderSheet(
  BuildContext context,
  OrderDetail order,
) => showModalBottomSheet<OrderDetail>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => CancelOrderSheet(order: order),
);

/// The reasons offered: payment reasons while the order awaits payment,
/// order reasons once it is placed (`CancelReasonEnum`).
List<CancelReason> cancelReasonsFor(OrderStatus status) =>
    status == OrderStatus.paymentPending
    ? const [
        CancelReason.changePaymentMethod,
        CancelReason.paymentProblem,
        CancelReason.orderedByMistake,
        CancelReason.changedMind,
        CancelReason.other,
      ]
    : const [
        CancelReason.orderedByMistake,
        CancelReason.changedMind,
        CancelReason.deliveryTooSlow,
        CancelReason.other,
      ];

/// The refund line for cancelling [order] (`08 §6.4` defaults, D-10).
///
/// PM default (P4 review): derived here from `payment_method` and
/// `payment_status` until the server offers a refund preview for a cancel;
/// revisit when D-10 is decided or such a preview lands. The rule:
/// paid online → full refund to the source in 5–7 working days; cash on
/// delivery → nothing due; not paid yet → nothing to refund. The amount is
/// the server's `grand_total`.
String cancelRefundText(AppLocalizations l10n, OrderDetail order) {
  if (order.status == OrderStatus.paymentPending) {
    return l10n.cancelRefundUnpaid;
  }
  return switch (order.paymentMethod) {
    PaymentMethod.cod => l10n.cancelRefundCod,
    _ when order.paymentStatus == PaymentStatus.paid => l10n.cancelRefundOnline(
      formatRupees(order.bill.grandTotal),
    ),
    _ => l10n.cancelRefundUnpaid,
  };
}

class CancelOrderSheet extends ConsumerStatefulWidget {
  const CancelOrderSheet({required this.order, super.key});

  final OrderDetail order;

  @override
  ConsumerState<CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends ConsumerState<CancelOrderSheet> {
  CancelReason? _reason;
  Object? _error;

  Future<void> _confirm() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _error = null);
    try {
      final cancelled = await ref
          .read(orderActionsProvider(widget.order.id).notifier)
          .cancel(reason);
      if (mounted && cancelled != null) Navigator.pop(context, cancelled);
    } catch (error) {
      if (!mounted) return;
      // Past the window by now (the store started packing): show the
      // server's current order behind the sheet.
      if (ApiError.from(error).code == ApiErrorCode.invalidStateTransition) {
        ref.invalidate(orderDetailProvider(widget.order.id));
      }
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy =
        ref.watch(orderActionsProvider(widget.order.id)) == OrderAction.cancel;
    final error = _error;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          JivoSpacing.gutter,
          0,
          JivoSpacing.gutter,
          JivoSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: const Key('cancel-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.cancelSheetTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            RadioGroup<CancelReason>(
              groupValue: _reason,
              onChanged: (value) {
                if (!busy) setState(() => _reason = value);
              },
              child: Column(
                children: [
                  for (final reason in cancelReasonsFor(widget.order.status))
                    RadioListTile<CancelReason>(
                      key: Key('reason-${reason.wireValue}'),
                      value: reason,
                      contentPadding: EdgeInsets.zero,
                      title: Text(cancelReasonLabel(l10n, reason)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: JivoSpacing.sm),
            Container(
              key: const Key('cancel-refund-info'),
              padding: const EdgeInsets.all(JivoSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(JivoRadii.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: JivoSpacing.sm),
                  Expanded(child: Text(cancelRefundText(l10n, widget.order))),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: JivoSpacing.md),
              Text(
                describeErrorWithDetails(context, error),
                key: const Key('cancel-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: JivoSpacing.lg),
            if (_reason == null)
              Padding(
                padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
                child: Text(
                  l10n.cancelChooseReason,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            BusyButton(
              key: const Key('cancel-confirm'),
              label: l10n.cancelConfirmAction,
              busy: busy,
              onPressed: _reason == null ? null : _confirm,
            ),
            const SizedBox(height: JivoSpacing.sm),
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: Text(l10n.keepOrder),
            ),
          ],
        ),
      ),
    );
  }
}
