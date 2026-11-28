import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/login_method.dart';

/// "Call support" and "Email support" (48 dp), for when an email is not a
/// rider's: the rider app cannot register a rider by email.
class SupportContactButtons extends ConsumerWidget {
  const SupportContactButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    void open(Uri uri) => unawaited(ref.read(urlOpenerProvider).open(uri));
    return Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          key: const Key('login-support-call'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () =>
              open(Uri(scheme: 'tel', path: RiderSupportContact.phone)),
          icon: const Icon(Icons.call),
          label: Text(l10n.loginSupportCall),
        ),
        TextButton.icon(
          key: const Key('login-support-email'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () =>
              open(Uri(scheme: 'mailto', path: RiderSupportContact.email)),
          icon: const Icon(Icons.email_outlined),
          label: Text(l10n.loginSupportEmail),
        ),
      ],
    );
  }
}
