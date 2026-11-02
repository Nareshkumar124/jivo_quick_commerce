import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dev_tools_button.dart';
import '../../auth/presentation/logout_button.dart';
import '../../launch/presentation/blocking_message.dart';

/// `rider_status: NONE` in staging and prod: the Phase 1 placeholder, kept
/// until the rider API lands (no fakes there). The dev flavor and `FAKE_API`
/// builds open `RegistrationScreen` instead.
class RegisterPlaceholderScreen extends StatelessWidget {
  const RegisterPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [LogoutButton()],
      ),
      body: BlockingMessage(
        icon: Icons.how_to_reg,
        title: l10n.registerTitle,
        body: l10n.registerBody,
        actions: const [DevToolsButton()],
      ),
    );
  }
}
