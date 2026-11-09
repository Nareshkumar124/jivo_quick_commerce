import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/routes.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/rider_error_text.dart';
import '../../../shared/format/ist_format.dart';
import '../../earnings/presentation/earnings_screen.dart';
import '../../support/domain/support_models.dart';
import '../../task/domain/rider_task.dart';
import '../../task/domain/task_rules.dart';
import '../../task/presentation/task_text.dart';
import '../domain/task_history.dart';
import 'history_providers.dart';
import 'history_screen.dart';

/// One past task (04 §2.8): how it ended, the route, the times, what was in
/// the bag, the cash collected and the pay lines. Every amount is the
/// server's; no customer personal data is shown (locality only).
class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({required this.taskId, super.key});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(taskHistoryDetailProvider(taskId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyDetailTitle)),
      body: switch (detail) {
        AsyncData(:final value) => _Detail(detail: value),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                Text(
                  riderApiErrorMessage(context, ApiError.from(error)),
                  key: const Key('history-detail-error'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('history-detail-retry'),
                  onPressed: () =>
                      ref.invalidate(taskHistoryDetailProvider(taskId)),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.detail});

  final TaskHistoryDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entry = detail.entry;
    final times = <(String, DateTime?)>[
      (l10n.historyAssignedAt, detail.assignedAt),
      (l10n.historyPickedUpAt, detail.pickedUpAt),
      (l10n.historyDeliveredAt, detail.deliveredAt),
      (l10n.historyFailedAt, detail.failedAt),
      (l10n.historyReturnedAt, detail.returnedAt),
      (l10n.historyCancelledAt, detail.cancelledAt),
    ];
    return ListView(
      key: const Key('history-detail'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.taskOrderNumber(entry.orderNumber),
          style: theme.textTheme.titleLarge,
        ),
        Text(
          historyStatusText(l10n, entry.status),
          key: const Key('history-detail-status'),
          style: theme.textTheme.titleMedium,
        ),
        if (detail.failReason case final reason?)
          Text(
            failReasonText(l10n, reason),
            key: const Key('history-detail-fail-reason'),
          ),
        const SizedBox(height: 8),
        Text(l10n.historyRoute(entry.storeName, entry.dropLocality)),
        if (entry.distanceKm != null)
          Text(distanceText(l10n, entry.distanceKm)),
        const Divider(height: 32),
        for (final (label, at) in times)
          if (at != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(istDateTime(context, at)),
                ],
              ),
            ),
        const Divider(height: 32),
        Text(
          l10n.historyItems(detail.itemCount),
          style: theme.textTheme.titleMedium,
        ),
        for (final item in detail.items)
          Text(
            [
              '${item.quantity} × ${item.name}',
              if (item.unit != null) item.unit!,
            ].join(' · '),
          ),
        const Divider(height: 32),
        Text(
          detail.paymentType == PaymentType.cod
              ? l10n.historyPaymentCod
              : l10n.historyPaymentPrepaid,
        ),
        if (detail.codCollected case final collected?)
          Text(
            l10n.historyCodCollected(formatRupees(collected)),
            key: const Key('history-detail-cod'),
            style: theme.textTheme.titleMedium,
          ),
        if (detail.earningsTotal case final total?) ...[
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.historyEarned,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                formatRupees(total),
                key: const Key('history-detail-earned'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          for (final line in detail.earningLines)
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      earningTypeText(l10n, line.type),
                      if (line.note != null) line.note!,
                    ].join(' · '),
                  ),
                ),
                Text(formatRupees(line.amount)),
              ],
            ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const Key('history-detail-help'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: () => context.push(
            Routes.newTicket(
              topic: RiderTicketTopic.task.code,
              reference: detail.entry.orderNumber,
            ),
          ),
          icon: const Icon(Icons.support_agent),
          label: Text(l10n.historyGetHelp),
        ),
      ],
    );
  }
}

/// The failed-delivery reason, as the rider chose it.
String failReasonText(AppLocalizations l10n, FailReason reason) =>
    switch (reason) {
      FailReason.notReachable => l10n.failNotReachable,
      FailReason.refused => l10n.failRefused,
      FailReason.wrongAddress => l10n.failWrongAddress,
      FailReason.other => l10n.failOther,
    };
