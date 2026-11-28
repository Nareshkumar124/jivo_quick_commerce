import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/errors/rider_error_text.dart';
import '../../../shared/widgets/dev_tools_button.dart';
import '../../../shared/widgets/resume_listener.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/logout_button.dart';
import '../../legal/presentation/account_menu_button.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../launch/presentation/blocking_message.dart';
import '../../launch/presentation/launch_controller.dart';

/// Static status screen: `SUSPENDED` and statuses this version does not
/// know, in every build. In staging and prod (no rider API yet, no fakes) it
/// is also the Phase 1 placeholder for `PENDING_KYC` and `REJECTED`; the dev
/// flavor and `FAKE_API` builds use `OnboardingStatusScreen` for those.
class RiderStatusScreen extends ConsumerStatefulWidget {
  const RiderStatusScreen({super.key});

  @override
  ConsumerState<RiderStatusScreen> createState() => _RiderStatusScreenState();
}

/// UX audit RA-06: the rider can check the status here ("Check status")
/// and it is checked again on every return to the app, so an approval
/// shows without closing and reopening the app. "Call support" is offered
/// in every status when `config/app` has a support phone.
class _RiderStatusScreenState extends ConsumerState<RiderStatusScreen> {
  bool _checking = false;

  Future<void> _check({bool quiet = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await ref.read(riderAccountControllerProvider.notifier).refreshStatus();
    } on Object catch (e) {
      if (mounted && !quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(riderApiErrorMessage(context, ApiError.from(e))),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return ResumeListener(
      onResume: () => unawaited(_check(quiet: true)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: const [AccountMenuButton(), LogoutButton()],
        ),
        body: BlockingMessage(
          icon: icon,
          title: title,
          body: body,
          actions: [
            // The server may send an empty support phone (local config does).
            if (supportPhone != null && supportPhone.trim().isNotEmpty)
              OutlinedButton.icon(
                key: const Key('call-support'),
                onPressed: () => ref
                    .read(urlOpenerProvider)
                    .open(Uri(scheme: 'tel', path: supportPhone)),
                icon: const Icon(Icons.call),
                label: Text(l10n.callSupport),
              ),
            FilledButton(
              key: const Key('status-check'),
              onPressed: _checking ? null : _check,
              child: _checking
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Text(l10n.statusActionCheck),
            ),
            const DevToolsButton(),
          ],
        ),
      ),
    );
  }
}
