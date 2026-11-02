import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import 'rider_account_controller.dart';

/// Log out (04 §2.9). Refused with a message while the rider is online.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const Key('logout'),
      tooltip: l10n.logout,
      icon: const Icon(Icons.logout),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final result = await ref
            .read(riderAccountControllerProvider.notifier)
            .logout();
        if (result == LogoutResult.blockedWhileOnline) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.logoutBlockedOnline)),
          );
        }
      },
    );
  }
}
