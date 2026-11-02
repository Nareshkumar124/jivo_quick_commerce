import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/launch_gate.dart';
import 'blocking_message.dart';
import 'launch_controller.dart';

/// Force update (blocking: no Back, no Later) when the installed version is
/// below `min_supported_version` or a call got 426; otherwise the optional
/// update prompt (below `latest_version`) with "Later".
class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});

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
    final forced = control is AppUpdateRequired;
    final storeUrl = control is AppUpdateRequired && control.storeUrl != null
        ? storeUriOf(control.storeUrl.toString())
        : launch.storeUrl;

    Future<void> openStore() async {
      final messenger = ScaffoldMessenger.of(context);
      final opened = await ref.read(urlOpenerProvider).open(storeUrl);
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.updateStoreOpenFailed)),
        );
      }
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BlockingMessage(
          icon: Icons.system_update,
          title: forced ? l10n.updateRequiredTitle : l10n.updateAvailableTitle,
          body: forced ? l10n.updateRequiredBody : l10n.updateAvailableBody,
          actions: [
            FilledButton(
              key: const Key('update-now'),
              onPressed: openStore,
              child: Text(l10n.updateNow),
            ),
            if (!forced)
              TextButton(
                key: const Key('update-later'),
                onPressed: () => ref
                    .read(launchControllerProvider.notifier)
                    .dismissSoftUpdate(),
                child: Text(l10n.updateLater),
              ),
          ],
        ),
      ),
    );
  }
}
