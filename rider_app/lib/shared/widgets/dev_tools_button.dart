import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/env.dart';
import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';

/// Opens the Phase 0 location spike. Renders nothing outside the dev flavor.
class DevToolsButton extends ConsumerWidget {
  const DevToolsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appEnvProvider).showDevTools) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const Key('dev-tools'),
      onPressed: () => context.push(Routes.locationDebug),
      icon: const Icon(Icons.bug_report),
      label: Text(AppLocalizations.of(context).homeDevToolsButton),
    );
  }
}
