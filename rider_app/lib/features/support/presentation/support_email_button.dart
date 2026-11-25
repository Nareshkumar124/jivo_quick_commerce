import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show AppConfig;

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';

/// `support.email` from `GET /config/app/`, or null when it is blank (then the
/// app shows no email button).
String? supportEmailOf(AppConfig? config) {
  final email = config?.support.email.trim();
  return email == null || email.isEmpty ? null : email;
}

/// "Email us" with the customer care address under it. Opens the mail app
/// (`mailto:`) the same way the call button opens the dialer.
class SupportEmailButton extends ConsumerWidget {
  const SupportEmailButton({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: () =>
          ref.read(urlOpenerProvider).open(Uri(scheme: 'mailto', path: email)),
      icon: const Icon(Icons.email_outlined),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.emailSupport),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}
