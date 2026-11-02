import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/env.dart';
import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/dev_tools_button.dart';
import '../../../shared/widgets/primary_action_bar.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/domain/rider_destination.dart';
import '../../auth/presentation/logout_button.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../launch/presentation/blocking_message.dart';
import '../../launch/presentation/launch_controller.dart';
import '../data/fake_rider_onboarding_backend.dart';
import '../domain/rider_profile.dart';
import 'onboarding_providers.dart';
import 'onboarding_text.dart';
import 'rider_status_screen.dart';

/// Approval status (04 §2.2, screen 6) and the hub of the application steps,
/// from `GET /rider/me/`:
/// - application incomplete: a checklist and the next step;
/// - pending review;
/// - rejected: the reason, the rejected documents and the re-upload path;
/// - approved: one tap to continue to home.
///
/// `SUSPENDED` and unknown statuses show the static [RiderStatusScreen].
class OnboardingStatusScreen extends ConsumerWidget {
  const OnboardingStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(riderAccountControllerProvider);
    final status = account is AccountLoaded
        ? account.riderStatus
        : RiderStatusEnum.unknownDefaultOpenApi;
    if (!canEditApplication(status)) return const RiderStatusScreen();

    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(riderProfileControllerProvider);
    final value = profile.value;
    if (value != null) {
      return _ProfileStatus(
        profile: value,
        busy: profile.isLoading,
        error: profile.hasError ? ApiError.from(profile.error!) : null,
      );
    }
    final Widget body;
    if (profile.hasError) {
      body = BlockingMessage(
        icon: Icons.cloud_off,
        title: l10n.onboardingLoadError,
        body: onboardingErrorText(context, ApiError.from(profile.error!)),
        actions: [
          FilledButton(
            key: const Key('status-retry'),
            onPressed: () =>
                ref.read(riderProfileControllerProvider.notifier).reload(),
            child: Text(l10n.retry),
          ),
        ],
      );
    } else {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.onboardingLoading),
          ],
        ),
      );
    }
    return Scaffold(appBar: _statusAppBar(l10n), body: body);
  }
}

AppBar _statusAppBar(AppLocalizations l10n) =>
    AppBar(title: Text(l10n.appTitle), actions: const [LogoutButton()]);

class _ProfileStatus extends ConsumerWidget {
  const _ProfileStatus({
    required this.profile,
    required this.busy,
    required this.error,
  });

  final RiderProfile profile;

  /// A reload is running.
  final bool busy;

  /// The last reload failed (the profile shown is the previous one).
  final ApiError? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(riderProfileControllerProvider.notifier);
    final errorText = error == null
        ? null
        : onboardingErrorText(context, error!);
    final supportPhone = ref
        .watch(launchControllerProvider)
        .config
        ?.support
        .phone;
    final canCallSupport =
        supportPhone != null && supportPhone.trim().isNotEmpty;
    final devReview =
        ref.watch(appEnvProvider).showDevTools &&
        ref.watch(riderOnboardingRepositoryProvider)
            is FakeRiderOnboardingBackend;

    void open(String route) => context.push(route);

    final Widget callSupport = OutlinedButton.icon(
      key: const Key('call-support'),
      onPressed: () => ref
          .read(urlOpenerProvider)
          .open(Uri(scheme: 'tel', path: supportPhone)),
      icon: const Icon(Icons.call),
      label: Text(l10n.callSupport),
    );

    switch (profile.stage) {
      case OnboardingStage.needsDocuments:
      case OnboardingStage.needsBankAccount:
        final documents = profile.stage == OnboardingStage.needsDocuments;
        return _StatusLayout(
          icon: Icons.assignment_outlined,
          title: l10n.statusFinishTitle,
          body: l10n.statusFinishBody,
          onRefresh: controller.reload,
          content: [_Checklist(profile: profile)],
          actions: PrimaryActionBar(
            buttonKey: const Key('status-next-step'),
            label: documents
                ? l10n.statusActionUploadDocuments
                : l10n.statusActionAddBank,
            onPressed: () =>
                open(documents ? Routes.documents : Routes.bankDetails),
            error: errorText,
            secondary: const [DevToolsButton()],
          ),
        );
      case OnboardingStage.inReview:
        return _StatusLayout(
          icon: Icons.hourglass_top,
          title: l10n.statusPendingTitle,
          body: l10n.statusPendingBody,
          onRefresh: controller.reload,
          content: [_Checklist(profile: profile)],
          actions: PrimaryActionBar(
            buttonKey: const Key('status-check'),
            label: l10n.statusActionCheck,
            busy: busy,
            onPressed: controller.reload,
            error: errorText,
            secondary: [
              OutlinedButton(
                key: const Key('status-view-documents'),
                onPressed: () => open(Routes.documents),
                child: Text(l10n.statusActionViewDocuments),
              ),
              if (devReview) _DevReviewButton(onDone: controller.reload),
              const DevToolsButton(),
            ],
          ),
        );
      case OnboardingStage.rejected:
        final fixDocuments = !profile.documentsComplete;
        return _StatusLayout(
          icon: Icons.report_gmailerrorred,
          iconColor: theme.colorScheme.error,
          title: l10n.statusRejectedTitle,
          body: l10n.statusRejectedFixBody,
          onRefresh: controller.reload,
          content: [
            if (profile.rejectionReason case final reason?
                when reason.trim().isNotEmpty)
              Card(
                key: const Key('status-rejection-reason'),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.statusRejectedReasonLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(reason, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ),
            for (final document in profile.rejectedDocuments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(documentName(l10n, document.type)),
                subtitle: document.reviewNote == null
                    ? null
                    : Text(document.reviewNote!),
              ),
          ],
          actions: PrimaryActionBar(
            buttonKey: const Key('status-fix'),
            label: fixDocuments
                ? l10n.statusActionFixDocuments
                : l10n.statusActionFixBank,
            onPressed: () =>
                open(fixDocuments ? Routes.documents : Routes.bankDetails),
            error: errorText,
            secondary: [
              if (canCallSupport) callSupport,
              const DevToolsButton(),
            ],
          ),
        );
      case OnboardingStage.approved:
        final store = profile.homeStore ?? profile.preferredStore;
        return _StatusLayout(
          icon: Icons.check_circle,
          title: l10n.statusApprovedTitle,
          body: l10n.statusApprovedBody(
            l10n.registerStoreOption(store.name, store.city),
          ),
          content: const [],
          actions: PrimaryActionBar(
            buttonKey: const Key('status-start'),
            label: l10n.statusActionStart,
            onPressed: controller.continueAsApproved,
          ),
        );
      // SUSPENDED: the account status follows the profile, so the static
      // screen replaces this on the next frame.
      case OnboardingStage.suspended:
        return _plainScaffold(
          l10n,
          BlockingMessage(
            icon: Icons.block,
            title: l10n.statusSuspendedTitle,
            body: l10n.statusSuspendedBody,
            actions: [if (canCallSupport) callSupport],
          ),
        );
      case OnboardingStage.unknown:
        return _plainScaffold(
          l10n,
          BlockingMessage(
            icon: Icons.help_outline,
            title: l10n.statusUnknownTitle,
            body: l10n.statusUnknownBody,
            actions: [if (canCallSupport) callSupport],
          ),
        );
    }
  }
}

Widget _plainScaffold(AppLocalizations l10n, Widget body) =>
    Scaffold(appBar: _statusAppBar(l10n), body: body);

/// Icon, title and body, then [content], scrollable (pull to refresh), with
/// the actions pinned at the bottom. The actions are the Scaffold's bottom
/// bar, so snack bars (e.g. "Bank details saved") appear above them instead
/// of covering the primary button.
class _StatusLayout extends StatelessWidget {
  const _StatusLayout({
    required this.icon,
    required this.title,
    required this.body,
    required this.content,
    required this.actions,
    this.iconColor,
    this.onRefresh,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String body;
  final List<Widget> content;
  final Widget actions;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      children: [
        Icon(icon, size: 72, color: iconColor ?? theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          key: const Key('status-title'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        ...content,
      ],
    );
    final refresh = onRefresh;
    return Scaffold(
      appBar: _statusAppBar(AppLocalizations.of(context)),
      body: refresh == null
          ? list
          : RefreshIndicator(onRefresh: refresh, child: list),
      bottomNavigationBar: actions,
    );
  }
}

/// The three application steps and how far each one is.
class _Checklist extends StatelessWidget {
  const _Checklist({required this.profile});

  final RiderProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rejected = profile.rejectedDocuments.length;
    final bank = profile.bankAccount;
    return Card(
      child: Column(
        children: [
          _ChecklistRow(
            key: const Key('step-details'),
            done: true,
            title: l10n.statusStepDetails,
            subtitle: l10n.statusStepDone,
          ),
          _ChecklistRow(
            key: const Key('step-documents'),
            done: profile.documentsComplete,
            problem: rejected > 0,
            title: l10n.statusStepDocuments,
            subtitle: profile.documentsComplete
                ? l10n.statusStepDone
                : rejected > 0
                ? l10n.statusStepDocumentsFix(rejected)
                : l10n.statusStepDocumentsProgress(
                    profile.documentsDone,
                    profile.requiredDocuments.length,
                  ),
          ),
          _ChecklistRow(
            key: const Key('step-bank'),
            done: bank != null,
            title: l10n.statusStepBank,
            subtitle: bank == null
                ? l10n.statusStepNeeded
                : l10n.bankSavedShort(bank.accountNumberMasked),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.done,
    required this.title,
    required this.subtitle,
    this.problem = false,
    super.key,
  });

  final bool done;
  final bool problem;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 64,
      leading: Icon(
        done
            ? Icons.check_circle
            : problem
            ? Icons.error_outline
            : Icons.radio_button_unchecked,
        color: done
            ? scheme.primary
            : problem
            ? scheme.error
            : scheme.outline,
        size: 32,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

/// Dev flavor with the fake only: plays the ops review that happens in the
/// admin panel (approve, or reject the PAN).
class _DevReviewButton extends ConsumerWidget {
  const _DevReviewButton({required this.onDone});

  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      key: const Key('dev-review'),
      icon: const Icon(Icons.science_outlined),
      label: Text(l10n.statusDevReview),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) {
          final repository = ref.read(riderOnboardingRepositoryProvider);
          void review(void Function(FakeRiderOnboardingBackend fake) action) {
            if (repository is FakeRiderOnboardingBackend) action(repository);
            Navigator.of(sheetContext).pop();
            onDone();
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const Key('dev-review-approve'),
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(l10n.statusDevApprove),
                  onTap: () => review((fake) => fake.approveCurrent()),
                ),
                ListTile(
                  key: const Key('dev-review-reject'),
                  leading: const Icon(Icons.cancel_outlined),
                  title: Text(l10n.statusDevReject),
                  onTap: () => review((fake) => fake.rejectCurrent()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
