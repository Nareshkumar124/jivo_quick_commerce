import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/paged_list_controller.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../task/domain/task_rules.dart';
import '../domain/cash_ledger.dart';
import 'cash_providers.dart';

/// Cash in hand and the ledger (04 §2.7, screen 16): COD collected per
/// order, deposits recorded by the store manager, adjustments, by date.
/// At the limit (the server's verdict) a "Deposit cash" banner explains
/// that only prepaid orders come until the rider deposits.
class CashScreen extends ConsumerWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(cashLedgerProvider);
    final notifier = ref.read(cashLedgerProvider.notifier);
    final summary = state.header;

    // Day headers are inserted between entries: grouping is display only,
    // no amounts are added up.
    final rows = <_CashRow>[
      for (final (day, entries) in groupByIstDay(state.items)) ...[
        _DayRow(day),
        for (final entry in entries) _EntryRow(entry),
      ],
    ];
    final display = PagedListState<_CashRow, CashSummary>(
      items: rows,
      header: state.header,
      nextPage: state.nextPage,
      loading: state.loading,
      loaded: state.loaded,
      error: state.error,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cashTitle)),
      body: PagedListView<_CashRow, CashSummary>(
        state: display,
        onRefresh: notifier.refresh,
        onLoadMore: notifier.loadMore,
        emptyText: l10n.cashEmpty,
        header: [
          if (summary != null) ...[
            if (summary.limitReached)
              Card(
                key: const Key('cash-limit-banner'),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cashDepositTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.cashDepositBody(formatRupees(summary.cashLimit)),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.cashInHand),
                    Text(
                      formatRupees(summary.cashInHand),
                      key: const Key('cash-in-hand'),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(l10n.cashLimit(formatRupees(summary.cashLimit))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        itemBuilder: (context, row) => switch (row) {
          _DayRow(:final day) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(
              istDate(context, day),
              key: Key('cash-day-${day.toIso8601String()}'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          _EntryRow(:final entry) => _EntryTile(entry: entry),
        },
      ),
    );
  }
}

/// One line of the ledger list: a day header or an entry.
sealed class _CashRow {
  const _CashRow();
}

class _DayRow extends _CashRow {
  const _DayRow(this.day);

  /// The IST date (UTC-midnight value).
  final DateTime day;
}

class _EntryRow extends _CashRow {
  const _EntryRow(this.entry);

  final CashEntry entry;
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final CashEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, title) = switch (entry.type) {
      CashEntryType.codCollected => (
        Icons.payments,
        switch (entry.orderNumber) {
          final order? => l10n.cashCodCollected(order),
          null => l10n.cashCodCollectedNoOrder,
        },
      ),
      CashEntryType.deposit => (Icons.account_balance, l10n.cashDeposit),
      CashEntryType.adjustment => (Icons.tune, l10n.cashAdjustment),
    };
    final negative = entry.amount.trim().startsWith('-');
    return Card(
      key: Key('cash-entry-${entry.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    [
                      istTime(context, entry.recordedAt),
                      if (entry.note != null) entry.note!,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    l10n.cashBalanceAfter(formatRupees(entry.balanceAfter)),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              formatRupees(entry.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: negative ? theme.colorScheme.error : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
