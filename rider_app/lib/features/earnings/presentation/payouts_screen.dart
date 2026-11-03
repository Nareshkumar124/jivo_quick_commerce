import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../task/domain/task_rules.dart';
import '../domain/earnings.dart';
import 'earnings_providers.dart';

/// Payout history (04 §2.8): period, amount, status and the bank
/// reference, as Finance recorded them.
class PayoutsScreen extends ConsumerWidget {
  const PayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(payoutsProvider);
    final notifier = ref.read(payoutsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.payoutsTitle)),
      body: PagedListView(
        state: state,
        onRefresh: notifier.refresh,
        onLoadMore: notifier.loadMore,
        emptyText: l10n.payoutsEmpty,
        itemBuilder: (context, payout) => _PayoutTile(payout: payout),
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final paid = payout.status == PayoutStatus.paid;
    return Card(
      key: Key('payout-${payout.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dateRange(
                      istDate(context, payout.periodStart),
                      istDate(context, payout.periodEnd),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paid ? l10n.payoutPaid : l10n.payoutPending,
                    key: Key('payout-${payout.id}-status'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: paid
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (payout.reference case final reference?)
                    Text(l10n.payoutReference(reference)),
                  if (payout.paidAt case final paidAt?)
                    Text(l10n.payoutPaidOn(istDayOf(context, paidAt))),
                ],
              ),
            ),
            Text(
              formatRupees(payout.amount),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
