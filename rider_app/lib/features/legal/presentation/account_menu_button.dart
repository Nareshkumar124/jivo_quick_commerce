import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../launch/presentation/launch_controller.dart';

/// The Terms of use and Privacy policy URLs from `GET /config/app/`
/// (`policy_urls`), or null where the config has none.
({Uri? terms, Uri? privacy}) policyUris(WidgetRef ref) {
  final urls = ref.watch(launchControllerProvider).config?.policyUrls;
  Uri? parse(String? raw) {
    final uri = Uri.tryParse(raw?.trim() ?? '');
    return uri != null && uri.hasScheme ? uri : null;
  }

  return (terms: parse(urls?.terms), privacy: parse(urls?.privacy));
}

enum _AccountMenuItem { terms, privacy, deleteAccount }

/// App-bar overflow menu for signed-in riders who are not ACTIVE yet
/// (registration and status screens): the Terms of use, the Privacy policy
/// and Delete account (Google Play: both must be reachable after login).
/// ACTIVE riders find the same entries on the profile screen.
class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uris = policyUris(ref);
    return PopupMenuButton<_AccountMenuItem>(
      key: const Key('account-menu'),
      tooltip: l10n.accountMenuTooltip,
      onSelected: (item) {
        switch (item) {
          case _AccountMenuItem.terms:
            if (uris.terms case final uri?) {
              unawaited(ref.read(urlOpenerProvider).open(uri));
            }
          case _AccountMenuItem.privacy:
            if (uris.privacy case final uri?) {
              unawaited(ref.read(urlOpenerProvider).open(uri));
            }
          case _AccountMenuItem.deleteAccount:
            unawaited(context.push(Routes.deleteAccount));
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          key: const Key('account-menu-terms'),
          value: _AccountMenuItem.terms,
          enabled: uris.terms != null,
          height: 56,
          child: Text(l10n.policyTermsOfUse),
        ),
        PopupMenuItem(
          key: const Key('account-menu-privacy'),
          value: _AccountMenuItem.privacy,
          enabled: uris.privacy != null,
          height: 56,
          child: Text(l10n.policyPrivacy),
        ),
        PopupMenuItem(
          key: const Key('account-menu-delete'),
          value: _AccountMenuItem.deleteAccount,
          height: 56,
          child: Text(l10n.deleteAccountTitle),
        ),
      ],
    );
  }
}
