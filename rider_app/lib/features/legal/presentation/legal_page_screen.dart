import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/rider_error_text.dart';
import '../../../shared/format/ist_format.dart';
import '../../../shared/widgets/safe_html_view.dart';
import '../../launch/presentation/launch_controller.dart';
import '../data/legal_repository.dart';
import 'legal_providers.dart';

/// A legal page from the CMS (04 §2.9, P7): the rider agreement, the
/// privacy policy and the background-location disclosure. The server HTML
/// is shown through `parseSafeHtml` (no web view, no scripts, only https,
/// mailto and tel links; `jivo:` links are ignored, the rider app has none).
///
/// A page the server doesn't have (404): privacy offers the `config/app`
/// policy URL; the location disclosure shows the app's own disclosure text
/// (the same words as the in-app prominent disclosure).
class LegalPageScreen extends ConsumerWidget {
  const LegalPageScreen({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final page = ref.watch(legalPageProvider(slug));
    final known = LegalSlug.fromSlug(slug);
    final missing =
        page.hasError &&
        ApiError.from(page.error!).code == ApiErrorCode.notFound;
    final privacyUrl = ref
        .watch(launchControllerProvider)
        .config
        ?.policyUrls
        .privacy;

    final Widget body;
    if (page case AsyncData(:final value)) {
      body = RefreshIndicator(
        onRefresh: () async => ref.invalidate(legalPageProvider(slug)),
        child: ListView(
          key: const Key('legal-page'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (value.blocks.isEmpty)
              Text(l10n.legalEmpty)
            else
              SafeHtmlView(
                blocks: value.blocks,
                onLink: (link) {
                  if (link.scheme == 'jivo') return;
                  ref.read(urlOpenerProvider).open(link);
                },
              ),
            if (value.page.updatedAt case final updatedAt?)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  l10n.legalUpdatedOn(istDate(context, updatedAt)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      );
    } else if (missing && known == LegalSlug.locationDisclosure) {
      body = ListView(
        key: const Key('legal-disclosure-fallback'),
        padding: const EdgeInsets.all(16),
        children: [
          for (final text in [
            l10n.disclosureBody,
            l10n.disclosureOnlineOnly,
            l10n.disclosureNotification,
            l10n.disclosureSharing,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
            ),
        ],
      );
    } else if (missing &&
        known == LegalSlug.privacy &&
        privacyUrl != null &&
        privacyUrl.startsWith('https://')) {
      body = _Message(
        key: const Key('legal-fallback'),
        text: l10n.legalNotPublished,
        action: l10n.legalOpenInBrowser,
        onAction: () => ref.read(urlOpenerProvider).open(Uri.parse(privacyUrl)),
      );
    } else if (missing) {
      body = _Message(
        key: const Key('legal-missing'),
        text: l10n.legalNotPublished,
      );
    } else if (page.hasError) {
      body = _Message(
        key: const Key('legal-error'),
        text: riderApiErrorMessage(context, ApiError.from(page.error!)),
        action: l10n.retry,
        onAction: () => ref.invalidate(legalPageProvider(slug)),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (page) {
          AsyncData(:final value) => value.page.title,
          _ => switch (known) {
            LegalSlug.riderAgreement => l10n.legalRiderAgreement,
            LegalSlug.privacy => l10n.legalPrivacy,
            LegalSlug.locationDisclosure => l10n.legalLocationDisclosure,
            null => '',
          },
        }),
      ),
      body: body,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction, super.key});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('legal-action'),
              style: FilledButton.styleFrom(minimumSize: const Size(160, 56)),
              onPressed: onAction,
              child: Text(action!),
            ),
          ],
        ],
      ),
    ),
  );
}
