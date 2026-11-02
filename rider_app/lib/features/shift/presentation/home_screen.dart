import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dev_tools_button.dart';
import '../../auth/presentation/logout_button.dart';
import '../../task/data/fake_task_backend.dart';
import '../../task/presentation/task_providers.dart';

/// Home for `ACTIVE` riders. Placeholder until P5 (online toggle, today
/// summary, current task); shows which flavor is running.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final env = ref.watch(appEnvProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [LogoutButton()],
      ),
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
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.homeBuildLabel(env.flavor.name),
                key: const Key('home-flavor'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.homePlaceholderBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(),
              const _DevOfferButtons(),
              const DevToolsButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dev flavor with the fake only: dispatch offers an order (prepaid or COD),
/// to walk through the offer and delivery screens on a phone.
class _DevOfferButtons extends ConsumerWidget {
  const _DevOfferButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(offerRepositoryProvider);
    if (!ref.watch(appEnvProvider).showDevTools ||
        !ref.watch(riderWorkActiveProvider) ||
        repository is! FakeTaskBackend) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('dev-offer-prepaid'),
              onPressed: () => repository.simulateOffer(),
              child: Text(l10n.devOfferPrepaid),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const Key('dev-offer-cod'),
              onPressed: () => repository.simulateOffer(cod: true),
              child: Text(l10n.devOfferCod),
            ),
          ),
        ],
      ),
    );
  }
}
