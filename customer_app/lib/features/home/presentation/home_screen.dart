import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_flow.dart';

/// Phase 1 placeholder for Home (`03 §2.5` arrives in Phase 2): greeting,
/// the optional-update prompt and one-time notices.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notice = ref.read(pendingNoticeProvider.notifier).take();
      if (notice == AppNotice.deletionCancelled) {
        showMessage(
          context,
          AppLocalizations.of(context).deletionCancelledNotice,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // LaunchState is a ChangeNotifier behind a plain Provider: rebuild on its
    // changes (update prompt dismissed, name edited).
    final launch = ref.watch(launchStateProvider);
    return ListenableBuilder(
      listenable: launch,
      builder: (context, _) => _build(context, launch),
    );
  }

  Widget _build(BuildContext context, LaunchState launch) {
    final l10n = AppLocalizations.of(context);
    final name = launch.user?.name ?? '';
    final storeUrl = launch.config?.storeUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.accountTitle,
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(Routes.account),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(JivoSpacing.gutter),
        children: [
          if (launch.showUpdatePrompt)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(JivoSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.updateAvailable),
                    Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: launch.dismissUpdatePrompt,
                          child: Text(l10n.later),
                        ),
                        if (storeUrl != null)
                          TextButton(
                            onPressed: () =>
                                ref.read(urlOpenerProvider).open(storeUrl),
                            child: Text(l10n.updateNow),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: JivoSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              l10n.homeGreeting(name),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: JivoSpacing.md),
          Text(l10n.homeComingSoon),
          const SizedBox(height: JivoSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.addresses),
            icon: const Icon(Icons.location_on_outlined),
            label: Text(l10n.addresses),
          ),
        ],
      ),
    );
  }
}
