import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/rider_error_text.dart';
import '../../launch/presentation/launch_controller.dart';
import '../../legal/data/legal_repository.dart';
import '../domain/support_models.dart';
import 'support_providers.dart';

/// Help and support (04 §2.9, screen 20; P7): call support, raise a ticket,
/// my tickets, the rider FAQs and the legal pages.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final supportPhone = ref
        .watch(launchControllerProvider)
        .config
        ?.support
        .phone;
    final canCall = supportPhone != null && supportPhone.trim().isNotEmpty;
    final faqs = ref.watch(faqsProvider);

    Widget row(String key, IconData icon, String label, VoidCallback onTap) =>
        ListTile(
          key: Key(key),
          minTileHeight: kRiderListRowMin,
          leading: Icon(icon, size: 28),
          title: Text(label, style: theme.textTheme.titleMedium),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(faqsProvider),
        child: ListView(
          key: const Key('help-list'),
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              key: const Key('help-raise-ticket'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => context.push(Routes.newTicket()),
              icon: const Icon(Icons.edit_note),
              label: Text(l10n.helpRaiseTicket),
            ),
            if (canCall) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('help-call-support'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                onPressed: () => ref
                    .read(urlOpenerProvider)
                    .open(Uri(scheme: 'tel', path: supportPhone)),
                icon: const Icon(Icons.call),
                label: Text(l10n.callSupport),
              ),
            ],
            const SizedBox(height: 8),
            Card(
              child: row(
                'help-my-tickets',
                Icons.forum_outlined,
                l10n.ticketsTitle,
                () => context.push(Routes.tickets),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.helpFaqTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            switch (faqs) {
              AsyncData(:final value) when value.isEmpty => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.helpFaqEmpty,
                  key: const Key('help-faq-empty'),
                ),
              ),
              AsyncData(:final value) => _FaqList(faqs: value),
              AsyncError(:final error) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    riderApiErrorMessage(context, ApiError.from(error)),
                    key: const Key('help-faq-error'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('help-faq-retry'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => ref.invalidate(faqsProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
              _ => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
            const SizedBox(height: 16),
            Text(l10n.legalTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final page in LegalSlug.values)
                    row(
                      'help-legal-${page.slug}',
                      Icons.description_outlined,
                      legalPageName(l10n, page),
                      () => context.push(Routes.legal(page.slug)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String legalPageName(AppLocalizations l10n, LegalSlug page) => switch (page) {
  LegalSlug.riderAgreement => l10n.legalRiderAgreement,
  LegalSlug.privacy => l10n.legalPrivacy,
  LegalSlug.locationDisclosure => l10n.legalLocationDisclosure,
};

class _FaqList extends StatelessWidget {
  const _FaqList({required this.faqs});

  final List<Faq> faqs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groupFaqs(faqs)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              group.category,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final faq in group.entries)
                  ExpansionTile(
                    key: Key('faq-${faq.id}'),
                    minTileHeight: kRiderListRowMin,
                    title: Text(
                      faq.question,
                      style: theme.textTheme.titleMedium,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(faq.answer, style: theme.textTheme.bodyLarge),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
