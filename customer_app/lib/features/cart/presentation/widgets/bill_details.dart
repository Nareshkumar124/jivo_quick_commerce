import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../domain/cart.dart';

/// The bill breakdown (`03 §2.8`): every row is the server's value from
/// `compute_bill` (`08 §6.2`), shown as sent. Nothing here adds, subtracts
/// or compares amounts; zero rows are hidden (except delivery, which shows
/// FREE) and the savings banner appears only when the server sends it.
class BillDetails extends StatelessWidget {
  const BillDetails({required this.bill, this.coupon, super.key});

  final CartBill bill;
  final AppliedCoupon? coupon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final success = context.jivoColors.success;
    String minus(String amount) => l10n.minusAmount(formatRupees(amount));
    final code = coupon?.code;
    final savings = bill.totalSavings;

    return Column(
      key: const Key('bill-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.billTitle, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: JivoSpacing.sm),
        _BillRow(
          rowKey: 'mrp-total',
          label: l10n.billItemTotal,
          value: formatRupees(bill.mrpTotal),
        ),
        if (!isZeroAmount(bill.productDiscount))
          _BillRow(
            rowKey: 'product-discount',
            label: l10n.billProductDiscount,
            value: minus(bill.productDiscount),
            valueColor: success,
          ),
        if (!isZeroAmount(bill.couponDiscount))
          _BillRow(
            rowKey: 'coupon-discount',
            label: code == null
                ? l10n.billCouponDiscount
                : l10n.billCouponDiscountCode(code),
            value: minus(bill.couponDiscount),
            valueColor: success,
          ),
        _BillRow(
          rowKey: 'delivery-fee',
          label: l10n.billDeliveryFee,
          value: isZeroAmount(bill.deliveryFee)
              ? l10n.billFree
              : formatRupees(bill.deliveryFee),
          valueColor: isZeroAmount(bill.deliveryFee) ? success : null,
        ),
        if (!isZeroAmount(bill.smallCartFee))
          _BillRow(
            rowKey: 'small-cart-fee',
            label: l10n.billSmallCartFee,
            value: formatRupees(bill.smallCartFee),
          ),
        if (!isZeroAmount(bill.handlingFee))
          _BillRow(
            rowKey: 'handling-fee',
            label: l10n.billHandlingFee,
            value: formatRupees(bill.handlingFee),
          ),
        if (!isZeroAmount(bill.tip))
          _BillRow(
            rowKey: 'tip',
            label: l10n.billTip,
            value: formatRupees(bill.tip),
          ),
        const Divider(height: JivoSpacing.xl),
        _BillRow(
          rowKey: 'to-pay',
          label: l10n.billToPay,
          value: formatRupees(bill.grandTotal),
          emphasised: true,
        ),
        if (!isZeroAmount(savings)) ...[
          const SizedBox(height: JivoSpacing.md),
          SavingsBanner(amount: savings),
        ],
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.rowKey,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasised = false,
  });

  final String rowKey;
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasised
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: JivoSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: style)),
            const SizedBox(width: JivoSpacing.md),
            Text(
              value,
              key: ValueKey('bill-$rowKey'),
              style: style?.copyWith(color: valueColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// "You save ₹X on this order", from the server's total savings.
class SavingsBanner extends StatelessWidget {
  const SavingsBanner({required this.amount, super.key});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final colors = context.jivoColors;
    return Container(
      key: const Key('bill-savings'),
      padding: const EdgeInsets.all(JivoSpacing.md),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, color: colors.success),
          const SizedBox(width: JivoSpacing.sm),
          Expanded(
            child: Text(
              AppLocalizations.of(context).billSavings(formatRupees(amount)),
              style: TextStyle(
                color: colors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
