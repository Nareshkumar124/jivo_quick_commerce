import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../profile/presentation/profile_form.dart';

/// New users: name (required) and email (optional) (`03 §2.2`). Saving
/// completes the profile and the router moves on.
class CompleteProfileScreen extends ConsumerWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(launchStateProvider).user;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(JivoSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: JivoSpacing.xl),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.completeProfileTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: JivoSpacing.sm),
                Text(l10n.completeProfileSubtitle),
                const SizedBox(height: JivoSpacing.xl),
                ProfileForm(
                  buttonLabel: l10n.continueLabel,
                  initialName: user?.name ?? '',
                  initialEmail: user?.email,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
