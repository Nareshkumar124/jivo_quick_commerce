import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../shared/html/safe_html.dart';
import '../data/legal_repository.dart';

/// The fake pages (`FAKE_API` builds). Overridden in tests.
final fakeLegalBackendProvider = Provider<FakeLegalBackend>(
  (ref) => FakeLegalBackend(),
);

/// `GET /pages/{slug}/` (public, every flavor); the fake with `FAKE_API`.
final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeLegalBackendProvider);
  }
  return ApiLegalRepository(ref.watch(jivoApiProvider));
});

/// A page with its HTML already reduced to safe blocks.
typedef ParsedLegalPage = ({LegalPage page, List<HtmlBlock> blocks});

final legalPageProvider = FutureProvider.autoDispose
    .family<ParsedLegalPage, String>((ref, slug) async {
      final page = await ref.watch(legalRepositoryProvider).page(slug);
      return (page: page, blocks: parseSafeHtml(page.html));
    });
