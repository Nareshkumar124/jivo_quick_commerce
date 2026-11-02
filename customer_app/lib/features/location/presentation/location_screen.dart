import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'location_options.dart';

/// Location permission / detect screen (`03 §3` #11): detect with GPS, pick
/// on the map, or choose a saved address.
class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.selectLocation)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(JivoSpacing.gutter),
            child: Column(
              children: [
                Icon(
                  Icons.location_on,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: JivoSpacing.sm),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.locationPrompt,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          LocationOptions(onChosen: () => context.go(Routes.home)),
        ],
      ),
    );
  }
}
