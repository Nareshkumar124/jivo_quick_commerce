import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import 'rider_account_controller.dart';

/// Log out (04 §2.9). Refused with a message while the rider is online or
/// has an active task.
class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const Key('logout'),
      tooltip: l10n.logout,
      icon: const Icon(Icons.logout),
      onPressed: () => logoutWithFeedback(context, ref),
    );
  }
}

/// Logs out after a confirmation, or explains in a snack bar why the rider
/// can't yet. A mis-tap must not log the rider out: getting back in needs
/// a new OTP (UX audit RA-11).
Future<void> logoutWithFeedback(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(riderAccountControllerProvider.notifier);

  void explain(LogoutResult? result) {
    final message = switch (result) {
      LogoutResult.blockedWhileOnline => l10n.logoutBlockedOnline,
      LogoutResult.blockedDuringTask => l10n.logoutBlockedDuringTask,
      LogoutResult.done || null => null,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  final blocked = await controller.logoutBlocker();
  if (blocked != null) {
    explain(blocked);
    return;
  }
  if (!context.mounted) return;
  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.logoutConfirmTitle),
      content: Text(l10n.logoutConfirmBody),
      actions: [
        TextButton(
          key: const Key('logout-cancel'),
          // Focus starts on Cancel.
          autofocus: true,
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l10n.logoutConfirmCancel),
        ),
        FilledButton(
          key: const Key('logout-confirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.logout),
        ),
      ],
    ),
  );
  if (yes != true) return;
  explain(await controller.logout());
}
