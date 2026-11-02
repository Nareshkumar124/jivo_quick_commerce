import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import 'blocking_message.dart';
import 'launch_controller.dart';

/// Maintenance mode (from `config/app` or a 503). "Try again" re-reads
/// `config/app`; once it says `maintenance: false` the signal is cleared and
/// the router continues.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launch = ref.watch(launchControllerProvider);
    final signals = ref.watch(appControlSignalsProvider);
    // Rebuild when a 426/503 arrives while this screen is already shown.
    return ListenableBuilder(
      listenable: signals,
      builder: (context, _) => _build(context, ref, launch, signals.current),
    );
  }

  Widget _build(
    BuildContext context,
    WidgetRef ref,
    LaunchState launch,
    AppControlEvent? control,
  ) {
    final l10n = AppLocalizations.of(context);
    final message = control is MaintenanceMode ? control.message?.trim() : null;
    final error = launch.error;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlockingMessage(
          icon: Icons.construction,
          title: l10n.maintenanceTitle,
          body: message == null || message.isEmpty
              ? l10n.maintenanceDefaultMessage
              : message,
          actions: [
            if (error != null && !launch.loading)
              Text(
                apiErrorMessage(JivoCoreLocalizations.of(context), error),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            FilledButton(
              key: const Key('maintenance-retry'),
              onPressed: launch.loading
                  ? null
                  : () => ref.read(launchControllerProvider.notifier).load(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
