import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import 'offer_alert_providers.dart';

/// Dev-only stand-in for the P5 offer screen. Opened by the test offer alert
/// (tap or full-screen intent), to prove the launch path end to end.
class OfferAlertPreviewScreen extends ConsumerWidget {
  const OfferAlertPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Future<void> dismiss() async {
      await ref.read(offerAlertNotificationsProvider).dismiss();
      if (!context.mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.home);
      }
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(offerAlertNotificationsProvider).dismiss();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.primaryContainer,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.delivery_dining,
                  size: 96,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.offerPreviewTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.offerPreviewBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: dismiss,
                  child: Text(l10n.offerPreviewDismiss),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
