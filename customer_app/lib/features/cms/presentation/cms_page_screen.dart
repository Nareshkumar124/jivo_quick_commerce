import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/html/safe_html.dart';
import '../../../shared/links/deep_links.dart';
import '../../../shared/widgets/safe_html_view.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/cms_repository.dart';

/// A CMS page with its HTML already reduced to safe blocks.
typedef ParsedCmsPage = ({CmsPage page, List<HtmlBlock> blocks});

final cmsPageProvider = FutureProvider.autoDispose
    .family<ParsedCmsPage, String>((ref, slug) async {
      final page = await ref.watch(cmsRepositoryProvider).page(slug);
      return (page: page, blocks: parseSafeHtml(page.html));
    });

/// CMS page viewer (`03 §2.11` Legal, screen #32; Phase 7 built ahead on
/// fakes): About, Terms, Privacy, Refund policy. The server HTML is shown
/// through [parseSafeHtml]: no web view, no scripts, only safe links.
class CmsPageScreen extends ConsumerWidget {
  const CmsPageScreen({required this.slug, super.key});

  final String slug;

  Future<void> _open(BuildContext context, WidgetRef ref, Uri link) async {
    if (link.scheme == 'jivo') {
      final location = deepLinkLocation(
        link,
        trackingAvailable: ref.read(trackingAvailableProvider),
      );
      if (location != null) await context.push(location);
      return;
    }
    await ref.read(urlOpenerProvider).open(link);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final page = ref.watch(cmsPageProvider(slug));
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (page) {
          AsyncData(:final value) => value.page.title,
          _ => '',
        }),
      ),
      body: switch (page) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(cmsPageProvider(slug)),
          child: ListView(
            key: const Key('cms-page'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(JivoSpacing.gutter),
            children: [
              if (value.blocks.isEmpty)
                Text(l10n.cmsPageEmpty)
              else
                SafeHtmlView(
                  blocks: value.blocks,
                  onLink: (link) => _open(context, ref, link),
                ),
              if (value.page.updatedAt case final updatedAt?)
                Padding(
                  padding: const EdgeInsets.only(top: JivoSpacing.lg),
                  child: Text(
                    l10n.cmsUpdatedOn(formatDate(updatedAt)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.invalidate(cmsPageProvider(slug)),
        ),
        _ => const SkeletonList(rows: 6),
      },
    );
  }
}
