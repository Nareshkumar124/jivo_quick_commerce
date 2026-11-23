import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../app/theme.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/presentation/auth_flow.dart';
import '../../cms/data/cms_repository.dart';
import '../../notifications/presentation/inbox_screen.dart';
import '../../referral/presentation/referral_controller.dart';
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
          padding: const EdgeInsets.fromLTRB(
            JivoSpacing.gutter,
            JivoSpacing.md,
            JivoSpacing.gutter,
            JivoSpacing.xl,
          ),
          children: [
            _ProfileHeader(name: value.name, phone: value.phone),
            const SizedBox(height: JivoSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QuickTile(
                    key: const Key('account-orders'),
                    icon: Icons.receipt_long_outlined,
                    label: l10n.myOrders,
                    onTap: () => context.push(Routes.orders),
                  ),
                ),
                const SizedBox(width: JivoSpacing.md),
                Expanded(
                  child: _QuickTile(
                    key: const Key('account-my-coupons'),
                    icon: Icons.local_offer_outlined,
                    label: l10n.myCoupons,
                    onTap: () => context.push(Routes.myCoupons),
                  ),
                ),
              ],
            ),
            const SizedBox(height: JivoSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QuickTile(
                    key: const Key('account-referral-tile'),
                    icon: Icons.card_giftcard_outlined,
                    label: l10n.referAFriend,
                    onTap: () => context.push(Routes.referral),
                  ),
                ),
                const SizedBox(width: JivoSpacing.md),
                Expanded(
                  child: _QuickTile(
                    key: const Key('account-addresses'),
                    icon: Icons.location_on_outlined,
                    label: l10n.addresses,
                    onTap: () => context.push(Routes.addresses),
                  ),
                ),
              ],
            ),
            const SizedBox(height: JivoSpacing.md),
            const _ReferralStrip(),
            const SizedBox(height: JivoSpacing.md),
            _Group(
              children: [
                _Row(
                  key: const Key('account-notifications'),
                  icon: Icons.notifications_none,
                  label: l10n.notificationsTitle,
                  trailing: const InboxUnreadBadge(),
                  onTap: () => context.push(Routes.notifications),
                ),
                _Row(
                  key: const Key('account-help'),
                  icon: Icons.help_outline,
                  label: l10n.helpTitle,
                  onTap: () => context.push(Routes.help),
                ),
                if (inAppPages)
                  for (final (label, slug, icon) in [
                    (l10n.aboutJivo, CmsSlugs.about, Icons.info_outline),
                    (
                      l10n.termsOfService,
                      CmsSlugs.terms,
                      Icons.description_outlined,
                    ),
                    (
                      l10n.privacyPolicy,
                      CmsSlugs.privacy,
                      Icons.privacy_tip_outlined,
                    ),
                    (l10n.refundPolicy, CmsSlugs.refund, Icons.currency_rupee),
                  ])
                    _Row(
                      key: Key('legal-$slug'),
                      icon: icon,
                      label: label,
                      onTap: () => context.push(Routes.page(slug)),
                    )
                else if (policies != null)
                  for (final (label, url, icon) in [
                    (
                      l10n.termsOfService,
                      policies.terms,
                      Icons.description_outlined,
                    ),
                    (
                      l10n.privacyPolicy,
                      policies.privacy,
                      Icons.privacy_tip_outlined,
                    ),
                    (l10n.refundPolicy, policies.refund, Icons.currency_rupee),
                  ])
                    _Row(
                      icon: icon,
                      label: label,
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => opener.open(url),
                    ),
              ],
            ),
            const SizedBox(height: JivoSpacing.md),
            _Group(
              children: [
                _Row(
                  key: const Key('account-logout'),
                  icon: Icons.logout,
                  label: l10n.logout,
                  onTap: () => _logout(context, ref),
                ),
                _Row(
                  icon: Icons.delete_outline,
                  label: l10n.deleteAccount,
                  danger: true,
                  onTap: () => context.push(Routes.deleteAccount),
                ),
              ],
            ),
            const SizedBox(height: JivoSpacing.lg),
            Center(
              child: Text(
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  final last = parts.length > 1 ? parts.last.characters.first : '';
  return (first + last).toUpperCase();
}

/// Keeps the country code and the last three digits.
String _maskPhone(String phone) {
  if (phone.length < 8) return phone;
  final tail = phone.substring(phone.length - 3);
  return '${phone.substring(0, 3)} ${'•' * (phone.length - 6)}$tail';
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.customerColors;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Home redesign: a white card (was the green gradient band).
    return Container(
      padding: const EdgeInsets.all(JivoSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(JivoRadii.lg),
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 30,
              backgroundColor: colors.softTint,
              child: Text(
                _initials(name),
                style: text.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: JivoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _maskPhone(phone),
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: JivoSpacing.sm),
                ActionChip(
                  key: const Key('account-edit'),
                  avatar: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: scheme.primary,
                  ),
                  label: Text(l10n.edit),
                  labelStyle: TextStyle(color: scheme.onPrimaryContainer),
                  backgroundColor: colors.softTint,
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: () => context.push(Routes.editProfile),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.customerColors;
    return Material(
      color: colors.softTint,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(JivoSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: JivoSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mint strip that opens Refer & earn. The amount comes from the referral
/// data; without it the text is generic.
class _ReferralStrip extends ConsumerWidget {
  const _ReferralStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.customerColors;
    final info = ref.watch(currentReferralProvider).value;
    final reward = info == null ? null : formatRupeesOrNull(info.rewardAmount);
    final active = info != null && info.isEnabled && reward != null;
    final green = Theme.of(context).colorScheme.primary;
    final ink = Theme.of(context).colorScheme.onPrimaryContainer;
    return Material(
      key: const Key('account-referral'),
      // Home redesign: pale mint with a green edge (was gold).
      color: colors.softTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.referral),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(JivoSpacing.md),
            child: Row(
              children: [
                Icon(Icons.card_giftcard, color: green),
                const SizedBox(width: JivoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active
                            ? l10n.referralHeadline(reward)
                            : l10n.referralStripGeneric,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: ink, fontWeight: FontWeight.w700),
                      ),
                      if (active && info.canApplyCode)
                        Text(
                          l10n.referralEntryHaveCode,
                          key: const Key('referral-have-code'),
                          style: TextStyle(color: ink),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 64),
          children[i],
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return ListTile(
      minTileHeight: 56,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: tint.withValues(alpha: 0.12),
        child: Icon(icon, size: 20, color: tint),
      ),
      title: Text(label, style: danger ? TextStyle(color: tint) : null),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
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
