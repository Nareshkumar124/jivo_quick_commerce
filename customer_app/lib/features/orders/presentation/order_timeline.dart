import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../domain/order_history.dart';
import 'order_texts.dart';

/// The status timeline (`03 §2.10`): Placed → Confirmed → Packing → On the
/// way → Delivered, each with the time it was reached; an order that ended
/// elsewhere ends with how it ended. Built by [buildTimeline] from the
/// server's status and history.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({required this.steps, super.key});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final success = context.jivoColors.success;

    return Column(
      key: const Key('order-timeline'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, step) in steps.indexed)
          Builder(
            builder: (context) {
              final ending = step.ending;
              final stage = step.stage;
              final label = ending != null
                  ? orderStatusLabel(l10n, ending)
                  : orderStageLabel(l10n, stage!);
              final bad = ending != null;
              final color = switch (step.state) {
                TimelineStepState.done => success,
                TimelineStepState.current =>
                  bad ? scheme.error : scheme.primary,
                TimelineStepState.upcoming => scheme.outlineVariant,
              };
              final stateText = switch (step.state) {
                TimelineStepState.done => l10n.orderStepDone,
                TimelineStepState.current => l10n.orderStepCurrent,
                TimelineStepState.upcoming => l10n.orderStepUpcoming,
              };
              final at = step.at;
              return MergeSemantics(
                child: Semantics(
                  value: stateText,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Column(
                            children: [
                              Icon(
                                switch (step.state) {
                                  TimelineStepState.done => Icons.check_circle,
                                  TimelineStepState.current =>
                                    bad
                                        ? Icons.cancel
                                        : Icons.radio_button_checked,
                                  TimelineStepState.upcoming =>
                                    Icons.radio_button_unchecked,
                                },
                                size: 20,
                                color: color,
                              ),
                              if (i < steps.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: step.state == TimelineStepState.done
                                        ? success
                                        : scheme.outlineVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: JivoSpacing.md),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: JivoSpacing.lg,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  key: Key('timeline-step-$i'),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight:
                                        step.state == TimelineStepState.upcoming
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                    color:
                                        step.state == TimelineStepState.upcoming
                                        ? scheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                                if (at != null)
                                  Text(
                                    formatDateTime(at),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
