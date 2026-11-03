import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
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
        child: ListView(
          key: const Key('home-list'),
          padding: const EdgeInsets.all(24),
          children: [
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
            const SizedBox(height: 24),
            const _RecordsMenu(),
            const _DevOfferButtons(),
            const DevToolsButton(),
          ],
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

/// The rider's own records (screens 15–18). Only where the records fake
/// runs (dev flavor) until the rider API lands.
class _RecordsMenu extends ConsumerWidget {
  const _RecordsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(riderWorkActiveProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    Widget item(String key, IconData icon, String label, String route) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            key: Key(key),
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
            onPressed: () => context.push(route),
            icon: Icon(icon),
            label: Text(label),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        item(
          'home-earnings',
          Icons.account_balance_wallet,
          l10n.earningsTitle,
          Routes.earnings,
        ),
        item('home-cash', Icons.payments, l10n.cashTitle, Routes.cash),
        item('home-history', Icons.history, l10n.historyTitle, Routes.history),
        item(
          'home-payouts',
          Icons.receipt_long,
          l10n.payoutsTitle,
          Routes.payouts,
        ),
        item('home-profile', Icons.person, l10n.profileTitle, Routes.profile),
        const SizedBox(height: 8),
      ],
    );
  }
}
