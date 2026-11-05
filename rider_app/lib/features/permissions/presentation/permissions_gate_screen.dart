import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/permission_gate.dart';
import 'permissions_gate_controller.dart';

/// Permissions checklist the rider must clear before going online (04 §2.1).
/// One primary action at a time: the button always fixes the next missing
/// item. Re-checks when the rider comes back from a settings page.
class PermissionsGateScreen extends ConsumerStatefulWidget {
  const PermissionsGateScreen({super.key});

  @override
  ConsumerState<PermissionsGateScreen> createState() =>
      _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends ConsumerState<PermissionsGateScreen> {
  late final AppLifecycleListener _lifecycle;

  PermissionsGateController get _controller =>
      ref.read(permissionsGateControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _controller.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _onPrimary(GateEvaluation evaluation) async {
    final next = evaluation.next;
    if (next == null) {
      if (context.canPop()) context.pop();
      return;
    }
    if (next.step == GateStep.disclosure) {
      final accepted = await context.push<bool>(Routes.disclosure);
      if (accepted ?? false) {
        await _controller.acceptDisclosure();
      } else {
        _controller.declineDisclosure();
      }
      return;
    }
    await _controller.fix(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gate = ref.watch(permissionsGateControllerProvider);
    final notices = ref.watch(gateNoticesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permissionsTitle)),
      body: switch (gate) {
        AsyncData(:final value) => _GateBody(
          evaluation: value,
          notices: notices,
          onPrimary: () => _onPrimary(value),
          onOpenAppSettings: _controller.openAppSettings,
          onOpenLocationAlwaysSettings: _controller.openLocationAlwaysSettings,
          onOpenFullScreenIntentSettings:
              _controller.openFullScreenIntentSettings,
        ),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.permissionsLoadError),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _controller.refresh,
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

class _GateBody extends StatelessWidget {
  const _GateBody({
    required this.evaluation,
    required this.notices,
    required this.onPrimary,
    required this.onOpenAppSettings,
    required this.onOpenLocationAlwaysSettings,
    required this.onOpenFullScreenIntentSettings,
  });

  final GateEvaluation evaluation;
  final GateNotices notices;
  final VoidCallback onPrimary;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenLocationAlwaysSettings;
  final VoidCallback onOpenFullScreenIntentSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final next = evaluation.next;
    final oem = evaluation.oemBrand;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  next == null ? l10n.permissionsAllSet : l10n.permissionsIntro,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                if (next == null)
                  const SizedBox.shrink()
                else if (next.step == GateStep.disclosure &&
                    notices.disclosureDeclined)
                  _NoticeCard(
                    key: const Key('gate-disclosure-declined'),
                    title: l10n.disclosureDeclinedTitle,
                    body: l10n.disclosureDeclinedBody,
                  )
                else if (next.step == GateStep.locationAlways &&
                    !next.blocked &&
                    notices.alwaysNotChosen)
                  _NoticeCard(
                    key: const Key('gate-always-not-chosen'),
                    title: l10n.gateAlwaysNotChosenTitle,
                    body: l10n.gateAlwaysNotChosenBody,
                    action: l10n.gateOpenAppSettings,
                    actionKey: const Key('gate-open-app-settings'),
                    onAction: onOpenLocationAlwaysSettings,
                  ),
                for (final item in evaluation.items) _GateRow(item: item),
                if (evaluation.fullScreenIntentMissing)
                  _AdvisoryCard(
                    icon: Icons.fullscreen,
                    title: l10n.fullScreenIntentTitle,
                    body: l10n.fullScreenIntentBody,
                    action: l10n.fullScreenIntentAction,
                    onAction: onOpenFullScreenIntentSettings,
                  ),
                if (oem != null)
                  // TODO(P5): replace with per-model guidance verified on the
                  // real-device matrix (10 §4); these are placeholders.
                  _AdvisoryCard(
                    icon: Icons.battery_alert,
                    title: l10n.oemTitle,
                    body: switch (oem) {
                      OemBrand.xiaomi => l10n.oemXiaomi,
                      OemBrand.oppo => l10n.oemOppo,
                      OemBrand.vivo => l10n.oemVivo,
                      OemBrand.realme => l10n.oemRealme,
                      OemBrand.oneplus => l10n.oemOneplus,
                    },
                    action: l10n.oemAction,
                    onAction: onOpenAppSettings,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('gate-primary'),
              onPressed: onPrimary,
              child: Text(_primaryLabel(l10n, next)),
            ),
          ),
        ],
      ),
    );
  }

  static String _primaryLabel(AppLocalizations l10n, GateItem? next) {
    if (next == null) return l10n.done;
    if (next.blocked) return l10n.gateActionOpenSettings;
    if (next.approximate) return l10n.gateActionLocationPrecise;
    return switch (next.step) {
      GateStep.disclosure => l10n.gateActionDisclosure,
      GateStep.locationWhenInUse => l10n.gateActionLocationWhenInUse,
      GateStep.locationAlways => l10n.gateActionLocationAlways,
      GateStep.notifications => l10n.gateActionNotifications,
      GateStep.batteryOptimisation => l10n.gateActionBattery,
      GateStep.gps => l10n.gateActionGps,
    };
  }
}

class _GateRow extends StatelessWidget {
  const _GateRow({required this.item});

  final GateItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (title, hint) = switch (item.step) {
      GateStep.disclosure => (
        l10n.gateStepDisclosure,
        l10n.gateStepDisclosureHint,
      ),
      GateStep.locationWhenInUse => (
        l10n.gateStepLocationWhenInUse,
        item.approximate
            ? l10n.gateStepLocationPreciseHint
            : l10n.gateStepLocationWhenInUseHint,
      ),
      GateStep.locationAlways => (
        l10n.gateStepLocationAlways,
        l10n.gateStepLocationAlwaysHint,
      ),
      GateStep.notifications => (
        l10n.gateStepNotifications,
        l10n.gateStepNotificationsHint,
      ),
      GateStep.batteryOptimisation => (
        l10n.gateStepBattery,
        l10n.gateStepBatteryHint,
      ),
      GateStep.gps => (l10n.gateStepGps, l10n.gateStepGpsHint),
    };
    final (icon, color, status) = item.done
        ? (Icons.check_circle, Colors.green.shade700, l10n.gateStatusDone)
        : item.blocked
        ? (Icons.block, scheme.error, l10n.gateStatusBlocked)
        : (Icons.radio_button_unchecked, scheme.outline, l10n.gateStatusNeeded);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 32),
      title: Text(title),
      subtitle: item.done ? null : Text(hint),
      trailing: Text(status, style: TextStyle(color: color)),
    );
  }
}

/// Why the next step is still open, in the rider's terms, with the way out.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.title,
    required this.body,
    this.action,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String body;
  final String? action;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: scheme.onErrorContainer)),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: actionKey,
                onPressed: onAction,
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdvisoryCard extends StatelessWidget {
  const _AdvisoryCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    ),
  );
}
