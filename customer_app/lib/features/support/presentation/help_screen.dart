import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/support_models.dart';
import 'support_controllers.dart';

/// Help & support (`03 §2.11`, screen #31; Phase 7 built ahead on fakes):
/// call support, "Get help with an order", my tickets and the FAQs.
///
/// Until the P7 support endpoints exist, the real-API build shows only
/// the call option ([supportAvailableProvider] false).
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final available = ref.watch(supportAvailableProvider);
    final phone = ref.watch(launchStateProvider).config?.supportPhone;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(faqsProvider),
        child: ListView(
          key: const Key('help'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (available) ...[
              ListTile(
                key: const Key('help-new-ticket'),
                leading: const Icon(Icons.support_agent),
                title: Text(l10n.helpWithOrder),
                subtitle: Text(l10n.helpWithOrderSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.newTicket()),
              ),
              ListTile(
                key: const Key('help-tickets'),
                leading: const Icon(Icons.forum_outlined),
                title: Text(l10n.myTickets),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.tickets),
              ),
            ],
            if (phone != null)
              ListTile(
                key: const Key('help-call'),
                leading: const Icon(Icons.call_outlined),
                title: Text(l10n.callSupport),
                subtitle: Text(phone),
                onTap: () => ref
                    .read(urlOpenerProvider)
                    .open(Uri(scheme: 'tel', path: phone)),
              ),
            if (!available && phone == null)
              Padding(
                padding: const EdgeInsets.all(JivoSpacing.gutter),
                child: Text(l10n.helpComingSoon),
              ),
            if (available) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  JivoSpacing.gutter,
                  JivoSpacing.md,
                  JivoSpacing.gutter,
                  JivoSpacing.sm,
                ),
                child: Semantics(
                  header: true,
                  child: Text(l10n.faqTitle, style: theme.textTheme.titleMedium),
                ),
              ),
              const _FaqSection(),
            ],
          ],
        ),
      ),
    );
  }
}

class _FaqSection extends ConsumerWidget {
  const _FaqSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return switch (ref.watch(faqsProvider)) {
      AsyncData(:final value) when value.isEmpty => Padding(
        padding: const EdgeInsets.all(JivoSpacing.gutter),
        child: Text(l10n.faqEmpty, key: const Key('faq-empty')),
      ),
      AsyncData(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (category, faqs) in groupFaqs(value)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                JivoSpacing.gutter,
                JivoSpacing.md,
                JivoSpacing.gutter,
                0,
              ),
              child: Text(category, style: theme.textTheme.titleSmall),
            ),
            for (final faq in faqs)
              ExpansionTile(
                key: Key('faq-${faq.id}'),
                title: Text(faq.question),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenPadding: const EdgeInsets.fromLTRB(
                  JivoSpacing.gutter,
                  0,
                  JivoSpacing.gutter,
                  JivoSpacing.md,
                ),
                children: [Text(faq.answer)],
              ),
          ],
        ],
      ),
      AsyncError(:final error) => SizedBox(
        height: 280,
        child: ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(faqsProvider),
        ),
      ),
      _ => const SizedBox(height: 240, child: SkeletonList(rows: 4)),
    };
  }
}

/// FAQs grouped by category, keeping the server's order.
List<(String, List<Faq>)> groupFaqs(List<Faq> faqs) {
  final groups = <String, List<Faq>>{};
  for (final faq in faqs) {
    groups.putIfAbsent(faq.category, () => []).add(faq);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}
