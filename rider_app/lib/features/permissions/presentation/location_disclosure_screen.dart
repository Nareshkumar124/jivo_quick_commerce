import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

/// Prominent disclosure for background location (Google Play User Data
/// policy). Shown in the normal app flow, before any location permission
/// request, and needs an explicit "Continue". Pops `true` when accepted.
///
/// The wording follows Play's required pattern: "[app] collects location data
/// to enable [features] even when the app is closed or not in use."
/// The consent button is affirmative ("I agree, turn on location", UX audit
/// RD-13). "Calculate your distance pay" stays out of the purposes until the
/// backend confirms whether pay uses the GPS trail (Play rejects purposes the
/// app does not have).
/// TODO(jivo-legal): review the text with the privacy policy (P7); the app
/// name must match the Play listing (D-11).
class LocationDisclosureScreen extends StatelessWidget {
  const LocationDisclosureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Icon(
                      Icons.my_location,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.disclosureTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.disclosureBody, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    _Point(
                      icon: Icons.toggle_on,
                      text: l10n.disclosureOnlineOnly,
                    ),
                    _Point(
                      icon: Icons.notifications_active,
                      text: l10n.disclosureNotification,
                    ),
                    _Point(
                      icon: Icons.share_location,
                      text: l10n.disclosureSharing,
                    ),
                    _Point(
                      icon: Icons.settings_suggest,
                      text: l10n.disclosureNextSteps,
                    ),
                  ],
                ),
              ),
              FilledButton(
                key: const Key('disclosure-accept'),
                onPressed: () => context.pop(true),
                child: Text(l10n.disclosureAccept),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('disclosure-decline'),
                onPressed: () => context.pop(false),
                child: Text(l10n.disclosureDecline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    ),
  );
}
