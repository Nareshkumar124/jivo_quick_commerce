import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dev_tools_button.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/logout_button.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../notifications/presentation/inbox_providers.dart';
import '../../notifications/presentation/inbox_screen.dart';
import '../../task/data/fake_task_backend.dart';
import '../../task/presentation/task_flow_controller.dart';
import '../../task/presentation/task_providers.dart';
import 'home_providers.dart';
import 'online_toggle.dart';
import 'shift_controller.dart';

/// Home for `ACTIVE` riders (04 §2.3, screen 8), to
/// `design/screens/rider/home.md` (UX audit RD-01): status card, guard card,
/// deposit banner, today tiles and the records, with the 72 dp online
/// control (or the current-task card) pinned at the bottom.
///
/// Builds without the rider work screens (staging and prod until the rider
/// API lands) keep the Phase 1 placeholder.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final env = ref.watch(appEnvProvider);
    final theme = Theme.of(context);
    final work = ref.watch(riderWorkActiveProvider);

    final buildLabel = Text(
      l10n.homeBuildLabel(env.flavor.name),
      key: const Key('home-flavor'),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall,
    );

    if (!work) {
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
              buildLabel,
              const SizedBox(height: 12),
              Icon(
                Icons.delivery_dining,
                size: 96,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.homePlaceholderBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const _RecordsMenu(),
              const DevToolsButton(),
            ],
          ),
        ),
      );
    }

    final account = ref.watch(riderAccountControllerProvider);
    final name = account is AccountLoaded ? account.user.name : null;
    final hasTask = ref.watch(
      taskFlowControllerProvider.select((s) => s.task != null),
    );

    Future<void> refresh() async {
      ref
        ..invalidate(todaySummaryProvider)
        ..invalidate(inboxUnreadCountProvider);
      await Future.wait([
        ref.read(shiftControllerProvider.notifier).sync(),
        ref.read(todaySummaryProvider.future).then((_) {}, onError: (_) {}),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          homeGreeting(l10n, name),
          key: const Key('home-greeting'),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          const InboxBellButton(),
          IconButton(
            key: const Key('home-appbar-profile'),
            tooltip: l10n.profileTitle,
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => context.push(Routes.profile),
            icon: const Icon(Icons.person),
          ),
          const LogoutButton(),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: refresh,
          child: SingleChildScrollView(
            key: const Key('home-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ShiftStatusCard(),
                const GuardCard(),
                const CashLimitBanner(),
                const SizedBox(height: 16),
                const TodaySummaryTiles(),
                const SizedBox(height: 16),
                const _RecordsMenu(),
                const _DevOfferButtons(),
                const DevToolsButton(),
                const SizedBox(height: 8),
                buildLabel,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.4,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: hasTask ? const CurrentTaskCard() : const OnlineControl(),
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

/// The rider's own records (screens 15–18). Only where the records fake
/// runs (dev flavor) until the rider API lands.
class _RecordsMenu extends ConsumerWidget {
  const _RecordsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(riderWorkActiveProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    Widget item(String key, IconData icon, String label, String route) =>
        ListTile(
          key: Key(key),
          minTileHeight: kRiderListRowMin,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: Icon(icon, size: 28),
          title: Text(label, style: Theme.of(context).textTheme.titleMedium),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
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
