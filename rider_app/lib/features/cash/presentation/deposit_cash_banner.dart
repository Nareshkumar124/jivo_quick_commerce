import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../task/domain/task_rules.dart';

/// "Deposit cash" (home §6 and the cash screen; UX audit RA-17): one
/// banner in the COD style (`rider.color.cod.*`, `warning` icon, title
/// 18 sp / 700, body 16 sp, 15.66:1) with "How to deposit". Shown only
/// when the server sends `deposit_required`; [limitReached] and
/// [cashLimit] are the server's values, nothing is computed.
///
/// [showLedgerLink]: the help sheet's "See cash ledger" button, left out
/// on the cash screen itself.
class DepositCashBanner extends StatelessWidget {
  const DepositCashBanner({
    required this.limitReached,
    required this.cashLimit,
    this.showLedgerLink = true,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  final bool limitReached;

  /// The server's limit; null shows "–".
  final String? cashLimit;
  final bool showLedgerLink;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = RiderColors.of(context);
    final limit = formatRupeeAmount(cashLimit) ?? missingAmountText;
    return Container(
      key: const Key('cash-limit-banner'),
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: colors.codDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning, color: colors.codBorder, size: 24),
              const SizedBox(width: 8),
              // RA-13: a longer translation wraps instead of overflowing.
              Expanded(
                child: Text(
                  l10n.cashDepositTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.codText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            limitReached
                ? l10n.cashDepositBody(limit)
                : l10n.cashDepositSkippedBody(limit),
            key: const Key('cash-limit-body'),
            style: TextStyle(fontSize: 16, color: colors.codText),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('cash-limit-how'),
            onPressed: () => _showHowTo(context),
            child: Text(l10n.homeHowToDeposit),
          ),
        ],
      ),
    );
  }

  Future<void> _showHowTo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.homeHowToDepositBody,
                key: const Key('cash-limit-how-body'),
                style: Theme.of(sheet).textTheme.bodyLarge,
              ),
              if (showLedgerLink) ...[
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('cash-limit-see-ledger'),
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    context.push(Routes.cash);
                  },
                  child: Text(l10n.homeSeeCashLedger),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
