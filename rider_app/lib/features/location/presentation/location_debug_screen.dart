import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../domain/location_service_client.dart';
import '../domain/tracker_stats.dart';
import '../domain/tracking_config.dart';
import 'location_debug_controller.dart';

/// Dev-flavor-only screen for the Phase 0 background-location spike.
/// Its Go online / Go offline button stands in for the P5 shift toggle.
class LocationDebugScreen extends ConsumerWidget {
  const LocationDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(locationDebugControllerProvider);
    final controller = ref.read(locationDebugControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    Future<void> toggleOnline() async {
      if (state.online) {
        await controller.goOffline();
        return;
      }
      final ok = await controller.goOnline(
        OnlineNotificationText(
          title: l10n.onlineNotificationTitle,
          body: l10n.onlineNotificationText,
          channelName: l10n.onlineChannelName,
          channelDescription: l10n.onlineChannelDescription,
        ),
      );
      if (!ok &&
          context.mounted &&
          ref.read(locationDebugControllerProvider).error ==
              LocationDebugError.permissionsMissing) {
        unawaited(context.push(Routes.permissions));
      }
    }

    Future<void> showTestOffer({required bool delayed}) async {
      final alerts = ref.read(offerAlertNotificationsProvider);
      final messenger = ScaffoldMessenger.of(context);
      Future<void> fire() => alerts.showTestOffer(
        title: l10n.testOfferTitle,
        body: l10n.testOfferBody,
        channelName: l10n.offerChannelName,
      );
      if (!delayed) return fire();
      messenger.showSnackBar(SnackBar(content: Text(l10n.debugOfferScheduled)));
      await Future<void>.delayed(const Duration(seconds: 10));
      await fire();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: state.online
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            child: ListTile(
              leading: Icon(
                state.online ? Icons.location_on : Icons.location_off,
                size: 32,
              ),
              title: Text(
                state.online ? l10n.debugStatusOnline : l10n.debugStatusOffline,
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(switch (state.error!) {
              LocationDebugError.permissionsMissing =>
                l10n.debugPermissionsMissing,
              LocationDebugError.startFailed => l10n.debugStartFailed(
                state.errorDetail ?? '',
              ),
              LocationDebugError.taskActive => l10n.offlineBlockedDuringTask,
            }, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.busy ? null : toggleOnline,
            child: Text(
              state.online ? l10n.debugGoOffline : l10n.debugGoOnline,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push(Routes.permissions),
            child: Text(l10n.debugPermissionsButton),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TrackingMode>(
            segments: [
              ButtonSegment(
                value: TrackingMode.idle,
                label: Text(l10n.debugModeIdle),
              ),
              ButtonSegment(
                value: TrackingMode.onTask,
                label: Text(l10n.debugModeOnTask),
              ),
            ],
            selected: {state.mode},
            onSelectionChanged: (s) => controller.setMode(s.first),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.debugSimulateOffline),
            value: state.simulateOffline,
            onChanged: controller.setSimulateOffline,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.debugSimulateServerOffline),
            value: state.simulateServerOffline,
            onChanged: controller.setSimulateServerOffline,
          ),
          OutlinedButton(
            onPressed: state.online ? controller.flush : null,
            child: Text(l10n.debugFlushNow),
          ),
          if (state.stats != null) ...[
            const SizedBox(height: 16),
            _StatsCard(stats: state.stats!),
          ],
          const Divider(height: 32),
          Text(
            l10n.debugOfferSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => showTestOffer(delayed: false),
            child: Text(l10n.debugOfferNow),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => showTestOffer(delayed: true),
            child: Text(l10n.debugOfferDelayed),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = DateFormat.Hms();
    final point = stats.lastPoint;
    final lines = <String>[
      l10n.debugStatsIntervals(
        stats.intervals.sample.inSeconds,
        stats.intervals.upload.inSeconds,
      ),
      l10n.debugStatsCounts(
        stats.buffered,
        stats.uploaded,
        stats.droppedOverflow,
        stats.rejected,
      ),
      if (point == null)
        l10n.debugStatsNoFix
      else
        l10n.debugStatsLastFix(
          point.lat.toStringAsFixed(5),
          point.lng.toStringAsFixed(5),
          point.accuracy?.toStringAsFixed(0) ?? '?',
          time.format(point.recordedAt.toLocal()),
        ),
      if (stats.lastUploadAt != null)
        l10n.debugStatsLastUpload(
          stats.lastUploadStatus.name,
          time.format(stats.lastUploadAt!.toLocal()),
        ),
      l10n.debugStatsLink(stats.consecutiveFailures, stats.heartbeats),
      if (stats.lastError != null) l10n.debugStatsLastError(stats.lastError!),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}
