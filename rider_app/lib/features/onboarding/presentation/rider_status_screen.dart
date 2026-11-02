import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dev_tools_button.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/logout_button.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../launch/presentation/blocking_message.dart';
import '../../launch/presentation/launch_controller.dart';

/// `PENDING_KYC`, `REJECTED`, `SUSPENDED` (or a status this version does not
/// know): placeholder status screen until the P5 KYC flow (04 §2.2).
class RiderStatusScreen extends ConsumerWidget {
  const RiderStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(riderAccountControllerProvider);
    final status = account is AccountLoaded
        ? account.riderStatus
        : RiderStatusEnum.unknownDefaultOpenApi;
    final supportPhone = ref
        .watch(launchControllerProvider)
        .config
        ?.support
        .phone;

    final (icon, title, body) = switch (status) {
      RiderStatusEnum.PENDING_KYC => (
        Icons.hourglass_top,
        l10n.statusPendingTitle,
        l10n.statusPendingBody,
      ),
      RiderStatusEnum.REJECTED => (
        Icons.report_gmailerrorred,
        l10n.statusRejectedTitle,
        l10n.statusRejectedBody,
      ),
      RiderStatusEnum.SUSPENDED => (
        Icons.block,
        l10n.statusSuspendedTitle,
        l10n.statusSuspendedBody,
      ),
      _ => (
        Icons.help_outline,
        l10n.statusUnknownTitle,
        l10n.statusUnknownBody,
      ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [LogoutButton()],
      ),
      body: BlockingMessage(
        icon: icon,
        title: title,
        body: body,
        actions: [
          // The server may send an empty support phone (local config does).
          if (supportPhone != null &&
              supportPhone.trim().isNotEmpty &&
              status != RiderStatusEnum.PENDING_KYC)
            OutlinedButton.icon(
              key: const Key('call-support'),
              onPressed: () => ref
                  .read(urlOpenerProvider)
                  .open(Uri(scheme: 'tel', path: supportPhone)),
              icon: const Icon(Icons.call),
              label: Text(l10n.callSupport),
            ),
          const DevToolsButton(),
        ],
      ),
    );
  }
}
