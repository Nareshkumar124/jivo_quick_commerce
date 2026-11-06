import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../onboarding/domain/validators.dart';
import '../../task/domain/task_rules.dart';
import '../domain/earnings.dart';
import 'earnings_providers.dart';
import '../../../shared/errors/rider_error_text.dart';

/// Earnings (04 §2.8, screen 15): today, this week or chosen dates. Every
/// amount, including all totals, is shown exactly as the server sends it.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  Future<void> _chooseDates(BuildContext context, WidgetRef ref) async {
    final today = istToday(ref.read(clockProvider)());
    final current = ref.read(earningsSelectionProvider).range;
    final picked = await showDateRangePicker(
      context: context,
      // Up to a year back (the API's limit is an open question).
      firstDate: DateTime(today.year - 1, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(
        start: DateTime(
          current.from.year,
          current.from.month,
          current.from.day,
        ),
        end: DateTime(current.to.year, current.to.month, current.to.day),
      ),
    );
    if (picked == null) return;
    ref
        .read(earningsSelectionProvider.notifier)
        .custom(DateRange(dateOnly(picked.start), dateOnly(picked.end)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.watch(earningsSelectionProvider);
    final earnings = ref.watch(earningsProvider);
    final notifier = ref.read(earningsSelectionProvider.notifier);

    // Only the selected dates' money is ever shown: while another period
    // loads (or after it failed) the previous period's figures are not.
    final value = earnings.value;
    final current =
        value != null &&
        value.from == selection.range.from &&
        value.to == selection.range.to;
    final Widget body;
    if (current && !earnings.hasError) {
      body = _Summary(summary: value);
    } else if (earnings.hasError && !earnings.isLoading) {
      body = _Error(
        error: ApiError.from(earnings.error!),
        onRetry: () => ref.invalidate(earningsProvider),
      );
    } else if (current) {
      // Pull-to-refresh of the same dates: keep them while reloading.
      body = _Summary(summary: value);
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.earningsTitle),
        actions: [
          TextButton(
            key: const Key('earnings-payouts'),
            onPressed: () => context.push(Routes.payouts),
            child: Text(l10n.payoutsTitle),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('period-today'),
                  label: Text(l10n.earningsToday),
                  selected: selection.period == EarningsPeriod.today,
                  onSelected: (_) => notifier.select(EarningsPeriod.today),
                ),
                ChoiceChip(
                  key: const Key('period-week'),
                  label: Text(l10n.earningsThisWeek),
                  selected: selection.period == EarningsPeriod.thisWeek,
                  onSelected: (_) => notifier.select(EarningsPeriod.thisWeek),
                ),
                ChoiceChip(
                  key: const Key('period-custom'),
                  label: Text(l10n.earningsChooseDates),
                  selected: selection.period == EarningsPeriod.custom,
                  onSelected: (_) => _chooseDates(context, ref),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.summary});

  final EarningsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = summary.from == summary.to
        ? istDate(context, summary.from)
        : l10n.dateRange(
            istDate(context, summary.from),
            istDate(context, summary.to),
          );
    return RefreshIndicator(
      onRefresh: () async {
        try {
          ref.invalidate(earningsProvider);
          await ref.read(earningsProvider.future);
        } on Object {
          // Shown by the screen (error with Retry).
        }
      },
      child: ListView(
        key: const Key('earnings-list'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(range, key: const Key('earnings-range')),
          const SizedBox(height: 4),
          Text(
            formatRupees(summary.total),
            key: const Key('earnings-total'),
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(l10n.earningsOrders(summary.ordersCount)),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                for (final type in EarningType.values)
                  if (summary.totalsByType[type] case final amount?)
                    _AmountRow(
                      key: Key('earnings-type-${type.wireValue}'),
                      label: earningTypeText(l10n, type),
                      amount: amount,
                    ),
              ],
            ),
          ),
          if (summary.orders.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.earningsPerOrder, style: theme.textTheme.titleMedium),
            for (final order in summary.orders)
              Card(
                key: Key('earnings-order-${order.orderNumber}'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AmountRow(
                        label: l10n.taskOrderNumber(order.orderNumber),
                        sublabel: istDateTime(context, order.completedAt),
                        amount: order.total,
                        bold: true,
                      ),
                      for (final line in order.lines)
                        _AmountRow(
                          label: earningTypeText(l10n, line.type),
                          amount: line.amount,
                          dense: true,
                        ),
                    ],
                  ),
                ),
              ),
            if (summary.ordersTruncated)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.earningsOrdersTruncated,
                  key: const Key('earnings-orders-truncated'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          if (summary.adjustments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l10n.earningsAdjustments, style: theme.textTheme.titleMedium),
            Card(
              child: Column(
                children: [
                  for (final adjustment in summary.adjustments)
                    _AmountRow(
                      label: earningTypeText(l10n, adjustment.line.type),
                      sublabel: [
                        if (adjustment.line.note != null) adjustment.line.note!,
                        istDateTime(context, adjustment.recordedAt),
                      ].join(' · '),
                      amount: adjustment.line.amount,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String earningTypeText(AppLocalizations l10n, EarningType type) =>
    switch (type) {
      EarningType.base => l10n.earningBase,
      EarningType.distance => l10n.earningDistance,
      EarningType.tip => l10n.earningTip,
      EarningType.incentive => l10n.earningIncentive,
      EarningType.penalty => l10n.earningPenalty,
    };

/// A label and an amount exactly as sent (negative amounts in red).
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.amount,
    this.sublabel,
    this.bold = false,
    this.dense = false,
    super.key,
  });

  final String label;
  final String? sublabel;
  final String amount;
  final bool bold;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = amount.trim().startsWith('-');
    final style =
        (dense ? theme.textTheme.bodyMedium : theme.textTheme.titleMedium)
            ?.copyWith(
              fontWeight: bold ? FontWeight.w700 : null,
              color: negative ? theme.colorScheme.error : null,
            );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 16,
        vertical: dense ? 2 : 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: dense ? theme.textTheme.bodyMedium : null),
                if (sublabel != null)
                  Text(sublabel!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(formatRupees(amount), style: style),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.error, required this.onRetry});

  final ApiError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 64),
          const SizedBox(height: 16),
          Text(
            riderApiErrorMessage(context, error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('earnings-retry'),
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    ),
  );
}
