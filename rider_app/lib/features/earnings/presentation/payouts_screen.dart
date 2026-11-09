import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../support/domain/support_models.dart';
import '../../task/domain/task_rules.dart';
import '../domain/earnings.dart';
import 'earnings_providers.dart';

/// Payout history (04 §2.8): period, amount, status and the bank
/// reference, as Finance recorded them, with "Get help" on each payout (a
/// PAYOUT ticket linked to it).
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
    final period = l10n.dateRange(
      istDate(context, payout.periodStart),
      istDate(context, payout.periodEnd),
    );
    return Card(
      key: Key('payout-${payout.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(period, style: theme.textTheme.titleMedium),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('payout-${payout.id}-help'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => context.push(
                  Routes.newTicket(
                    topic: RiderTicketTopic.payout.code,
                    payoutId: payout.id,
                    label: period,
                  ),
                ),
                icon: const Icon(Icons.support_agent),
                label: Text(l10n.payoutGetHelp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
