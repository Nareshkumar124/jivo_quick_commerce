import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/paged_list_view.dart';
import '../../task/domain/task_rules.dart';
import '../../task/domain/task_status.dart';
import '../../task/presentation/task_text.dart';
import '../domain/task_history.dart';
import 'history_providers.dart';

/// Past tasks (04 §2.8, screen 17): order number, date, store to drop,
/// distance, payout and how it ended.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(taskHistoryProvider);
    final notifier = ref.read(taskHistoryProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: PagedListView(
        state: state,
        onRefresh: notifier.refresh,
        onLoadMore: notifier.loadMore,
        emptyText: l10n.historyEmpty,
        itemBuilder: (context, entry) => _HistoryTile(entry: entry),
      ),
    );
  }
}

String historyStatusText(AppLocalizations l10n, TaskStatus status) =>
    switch (status) {
      TaskStatus.delivered => l10n.historyDelivered,
      TaskStatus.returned => l10n.historyReturned,
      TaskStatus.cancelled => l10n.historyCancelled,
      TaskStatus.failed || TaskStatus.returning => l10n.historyFailed,
      _ => l10n.historyOther,
    };

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final TaskHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final delivered = entry.status == TaskStatus.delivered;
    return Card(
      key: Key('history-${entry.taskId}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.taskOrderNumber(entry.orderNumber),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  historyStatusText(l10n, entry.status),
                  key: Key('history-${entry.taskId}-status'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: delivered
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            Text(istDateTime(context, entry.completedAt)),
            const SizedBox(height: 4),
            Text(l10n.historyRoute(entry.storeName, entry.dropLocality)),
            Row(
              children: [
                // Keeps the payout on the right when there is no distance.
                Expanded(
                  child: entry.distanceKm == null
                      ? const SizedBox.shrink()
                      : Text(distanceText(l10n, entry.distanceKm)),
                ),
                if (entry.payout case final payout?)
                  Text(
                    formatRupees(payout),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
