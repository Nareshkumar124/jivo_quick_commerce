import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import 'launch_controller.dart';

/// Blocking "Update required" (`03 §2.1`). Back can't leave it.
class ForceUpdateScreen extends ConsumerWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final event = ref.watch(appControlProvider).current;
    final storeUrl = event is AppUpdateRequired ? event.storeUrl : null;
    return PopScope(
      canPop: false,
      child: _BlockingPage(
        icon: Icons.system_update_outlined,
        title: l10n.updateRequiredTitle,
        body: l10n.updateRequiredBody,
        action: storeUrl == null
            ? null
            : FilledButton(
                onPressed: () async {
                  final opened = await ref
                      .read(urlOpenerProvider)
                      .open(storeUrl);
                  if (!opened && context.mounted) {
                    showMessage(context, l10n.linkOpenFailed);
                  }
                },
                child: Text(l10n.updateNow),
              ),
      ),
    );
  }
}

/// Full-screen maintenance message from config (`03 §2.1`).
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      await ref.read(refreshConfigProvider)();
    } catch (error) {
      if (mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final event = ref.watch(appControlProvider).current;
    final message = event is MaintenanceMode ? event.message : null;
    return PopScope(
      canPop: false,
      child: _BlockingPage(
        icon: Icons.construction_outlined,
        title: l10n.maintenanceTitle,
        body: message ?? l10n.maintenanceDefaultBody,
        action: BusyButton(
          label: l10n.tryAgain,
          busy: _checking,
          onPressed: _retry,
        ),
      ),
    );
  }
}

class _BlockingPage extends StatelessWidget {
  const _BlockingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(JivoSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: JivoSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: JivoSpacing.md),
                Text(body, textAlign: TextAlign.center),
                if (action != null) ...[
                  const SizedBox(height: JivoSpacing.xl),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
