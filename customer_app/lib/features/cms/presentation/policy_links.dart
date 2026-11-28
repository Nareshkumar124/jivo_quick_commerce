import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Opens a policy page (`terms`, `privacy`, `refund-policy`,
/// `delivery-policy`, `contact`, `delete-account`): the in-app viewer where
/// [cmsAvailableProvider] is on, otherwise its web URL
/// ([PolicyLinks.forSlug]) in the browser. Shows "couldn't open the link"
/// when neither works.
Future<void> openPolicyPage(
  BuildContext context,
  WidgetRef ref,
  String slug,
) async {
  if (ref.read(cmsAvailableProvider)) {
    await context.push(Routes.page(slug));
    return;
  }
  final url = ref.read(launchStateProvider).config?.policies.forSlug(slug);
  final opened = url != null && await ref.read(urlOpenerProvider).open(url);
  if (!opened && context.mounted) {
    showMessage(context, AppLocalizations.of(context).linkOpenFailed);
  }
}
