import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'launch_controller.dart';

/// Loads `config/app` (and the user when signed in); the router then moves
/// on (`03 §2.1`). Errors show with Retry.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(splashControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(JivoSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.appTitle,
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: JivoSpacing.xxl),
                if (status.hasError && !status.isLoading) ...[
                  Text(
                    l10n.splashFailedTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: JivoSpacing.sm),
                  Text(
                    describeErrorWithDetails(context, status.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: JivoSpacing.xl),
                  FilledButton(
                    onPressed: () => ref.invalidate(splashControllerProvider),
                    child: Text(l10n.retry),
                  ),
                ] else ...[
                  const ExcludeSemantics(child: CircularProgressIndicator()),
                  const SizedBox(height: JivoSpacing.lg),
                  Text(l10n.splashChecking, textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
