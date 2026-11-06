import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../cms/data/cms_repository.dart';
import '../../notifications/presentation/inbox_screen.dart';
import 'profile_controllers.dart';
import 'profile_form.dart';

/// Account (`03 §2.11`): profile, addresses, legal, version, logout, delete.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(logoutProvider)();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final policies = ref.watch(launchStateProvider).config?.policies;
    final version = ref.watch(clientInfoProvider).appVersion;
    final opener = ref.read(urlOpenerProvider);
    final inAppPages = ref.watch(cmsAvailableProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: switch (user) {
        AsyncData(:final value) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(value.name),
              subtitle: Text([value.phone, ?value.email].join('\n')),
              isThreeLine: value.email != null,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editProfile),
              onTap: () => context.push(Routes.editProfile),
            ),
            ListTile(
              key: const Key('account-orders'),
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(l10n.myOrders),
              onTap: () => context.push(Routes.orders),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l10n.addresses),
              onTap: () => context.push(Routes.addresses),
            ),
            ListTile(
              key: const Key('account-notifications'),
              leading: const Icon(Icons.notifications_none),
              title: Text(l10n.notificationsTitle),
              trailing: const InboxUnreadBadge(),
              onTap: () => context.push(Routes.notifications),
            ),
            ListTile(
              key: const Key('account-help'),
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.helpTitle),
              onTap: () => context.push(Routes.help),
            ),
            if (inAppPages) ...[
              const Divider(),
              ListTile(
                title: Text(
                  l10n.legal,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final (label, slug) in [
                (l10n.aboutJivo, CmsSlugs.about),
                (l10n.termsOfService, CmsSlugs.terms),
                (l10n.privacyPolicy, CmsSlugs.privacy),
                (l10n.refundPolicy, CmsSlugs.refund),
              ])
                ListTile(
                  key: Key('legal-$slug'),
                  title: Text(label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.page(slug)),
                ),
            ] else if (policies != null) ...[
              const Divider(),
              ListTile(
                title: Text(
                  l10n.legal,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final (label, url) in [
                (l10n.termsOfService, policies.terms),
                (l10n.privacyPolicy, policies.privacy),
                (l10n.refundPolicy, policies.refund),
              ])
                ListTile(
                  title: Text(label),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => opener.open(url),
                ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(l10n.logout),
              onTap: () => _logout(context, ref),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.deleteAccount,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => context.push(Routes.deleteAccount),
            ),
            ListTile(
              title: Text(
                l10n.appVersion(version),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.read(currentUserProvider.notifier).reload(),
        ),
        _ => const SkeletonList(rows: 4),
      },
    );
  }
}

/// Edit name and email; the phone is shown but not editable (`03 §2.11`).
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfile)),
      body: switch (user) {
        AsyncData(:final value) => SingleChildScrollView(
          padding: const EdgeInsets.all(JivoSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: value.phone,
                enabled: false,
                decoration: InputDecoration(
                  labelText: l10n.phoneLabel,
                  helperText: l10n.phoneNotEditable,
                ),
              ),
              const SizedBox(height: JivoSpacing.lg),
              ProfileForm(
                buttonLabel: l10n.save,
                initialName: value.name,
                initialEmail: value.email,
                onSaved: () {
                  showMessage(context, l10n.profileSaved);
                  context.pop();
                },
              ),
            ],
          ),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: () => ref.read(currentUserProvider.notifier).reload(),
        ),
        _ => const SkeletonList(rows: 2),
      },
    );
  }
}

/// Delete account (`03 §2.2`): explain the 30-day grace period, confirm by
/// OTP, show when the data is anonymised, then sign out.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static const otpFieldKey = Key('delete-otp');

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _reason = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    _otp.dispose();
    super.dispose();
  }

  String? _errorText(AppLocalizations l10n, Object? error) {
    if (error == null) return null;
    if (isApiError(error, ApiErrorCode.permissionDenied)) {
      return l10n.staffCannotDelete;
    }
    return describeErrorWithDetails(context, error);
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(deleteAccountProvider.notifier);
    final deletion = await controller.confirm(
      otp: _otp.text.trim(),
      reason: _reason.text,
    );
    if (deletion == null || !mounted) return;
    // Show the result first; signing out moves the router to login.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountDeletedTitle),
        content: Text(
          l10n.accountDeletedBody(formatDate(deletion.anonymiseAfter)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    await controller.finish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(deleteAccountProvider);
    final phone = ref.watch(launchStateProvider).user?.phone ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(JivoSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.deleteAccountExplainer),
            const SizedBox(height: JivoSpacing.lg),
            TextField(
              controller: _reason,
              maxLines: 3,
              maxLength: 500,
              enabled: state.step == DeleteStep.explain,
              decoration: InputDecoration(labelText: l10n.deleteReasonLabel),
            ),
            const SizedBox(height: JivoSpacing.lg),
            if (state.step == DeleteStep.explain) ...[
              if (state.error != null)
                Text(
                  _errorText(l10n, state.error)!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: JivoSpacing.md),
              BusyButton(
                label: l10n.sendOtpToConfirm,
                busy: state.busy,
                onPressed: phone.isEmpty
                    ? null
                    : () => ref
                          .read(deleteAccountProvider.notifier)
                          .sendOtp(phone),
              ),
            ] else ...[
              Text(l10n.deleteOtpSentTo(phone)),
              const SizedBox(height: JivoSpacing.md),
              TextField(
                key: DeleteAccountScreen.otpFieldKey,
                controller: _otp,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    state.challenge?.otpLength ?? 6,
                  ),
                ],
                decoration: InputDecoration(
                  labelText: l10n.otpLabel,
                  errorText: _errorText(l10n, state.error),
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: JivoSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: state.busy ? null : _confirm,
                  child: state.busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.deleteMyAccount),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
