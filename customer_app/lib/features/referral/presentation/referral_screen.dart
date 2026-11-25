import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/referral.dart';
import 'referral_controller.dart';

/// The reward as words: "1 free carton" for a free-carton reward (ADR
/// 0002), else the server's amount as rupees ("₹90"). Null when a ₹ amount
/// can't be shown. All referral copy below goes through it, so a free
/// carton is never shown as a ₹ amount.
String? referralRewardLabel(AppLocalizations l10n, ReferralInfo info) =>
    info.isFreeCarton
    ? l10n.freeCartonCount(info.rewardQuantity)
    : formatRupeesOrNull(info.rewardAmount);

String _reward(AppLocalizations l10n, ReferralInfo info) =>
    referralRewardLabel(l10n, info) ?? info.rewardAmount;

/// "You and your friend each get 1 free carton" or "you both get ₹90
/// off" (the headline and the Account strip).
String referralHeadlineText(AppLocalizations l10n, ReferralInfo info) =>
    info.isFreeCarton
    ? l10n.referralHeadlineReward(_reward(l10n, info))
    : l10n.referralHeadline(_reward(l10n, info));

/// The Account row: "Refer & earn 1 free carton" / "Refer & earn ₹90";
/// null when there is no reward to name.
String? referralAccountTitle(AppLocalizations l10n, ReferralInfo info) {
  final reward = referralRewardLabel(l10n, info);
  if (reward == null) return null;
  return info.isFreeCarton
      ? l10n.referAndEarnReward(reward)
      : l10n.referAndEarn(reward);
}

/// Rule 3: what both get after the first delivery, and how long it lasts.
String referralStep3Text(AppLocalizations l10n, ReferralInfo info) =>
    info.isFreeCarton
    ? l10n.referralStep3Reward(_reward(l10n, info), info.rewardValidityDays)
    : l10n.referralStep3(_reward(l10n, info), info.rewardValidityDays);

/// The confirmation after entering a friend's code.
String referralAppliedText(AppLocalizations l10n, ReferralInfo info) =>
    info.isFreeCarton
    ? l10n.referralAppliedReward(_reward(l10n, info))
    : l10n.referralApplied(_reward(l10n, info));

/// The checkout card's body.
String referralPromptText(AppLocalizations l10n, ReferralInfo info) =>
    info.isFreeCarton
    ? l10n.referralPromptBodyReward(_reward(l10n, info))
    : l10n.referralPromptBody(_reward(l10n, info));

/// The "You joined with code" card's status line; null for a status this
/// build does not know.
String? referralStatusText(
  AppLocalizations l10n,
  ReferralInfo info,
  ReferralStatus status,
) => switch (status) {
  ReferralStatus.pending when info.isFreeCarton =>
    l10n.referralStatusPendingReward(_reward(l10n, info)),
  ReferralStatus.pending => l10n.referralStatusPending(_reward(l10n, info)),
  ReferralStatus.rewarded when info.isFreeCarton =>
    l10n.referralStatusRewardedReward,
  ReferralStatus.rewarded => l10n.referralStatusRewarded(_reward(l10n, info)),
  ReferralStatus.noReward => l10n.referralStatusNoReward,
  ReferralStatus.unknown => null,
};

/// Account row that opens the referral screen. Names the reward once it is
/// known, and invites a new customer to enter a friend's code.
class ReferralAccountTile extends ConsumerWidget {
  const ReferralAccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final info = ref.watch(currentReferralProvider).value;
    final title = info == null ? null : referralAccountTitle(l10n, info);
    final active = info != null && info.isEnabled && title != null;
    return ListTile(
      key: const Key('account-referral'),
      leading: const Icon(Icons.card_giftcard_outlined),
      title: Text(active ? title : l10n.referAFriend),
      subtitle: active && info.canApplyCode
          ? Text(
              l10n.referralEntryHaveCode,
              key: const Key('referral-have-code'),
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.referral),
    );
  }
}

/// Refer & earn: the customer's code with Copy and Share, the rules, the
/// counts, and "Have a referral code?" for a new customer.
class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  static const codeFieldKey = Key('referral-code-field');
  static const applyKey = Key('referral-apply');

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fresh counts and status each time; a first load needs no reload.
    final userId = ref.read(signedInUserIdProvider);
    if (userId != null && ref.exists(referralProvider(userId))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(referralProvider(userId));
      });
    }
  }

  /// Loads the signed-in user's referral screen again.
  void _reload() {
    final userId = ref.read(signedInUserIdProvider);
    if (userId != null) ref.invalidate(referralProvider(userId));
  }

  Future<void> _pullToRefresh() async {
    final userId = ref.read(signedInUserIdProvider);
    if (userId == null) return;
    await refreshQuietly(ref.refresh(referralProvider(userId).future));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    final applied = await ref
        .read(referralApplyProvider.notifier)
        .apply(_code.text);
    if (!applied || !mounted) return;
    _code.clear();
    final info = ref.read(currentReferralProvider).value;
    if (info != null) showMessage(context, referralAppliedText(l10n, info));
  }

  Future<void> _copyCode(ReferralInfo info) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: info.code));
    if (mounted) showMessage(context, l10n.referralCodeCopied(info.code));
  }

  /// No share sheet package in the app yet: copy the server's message.
  Future<void> _share(ReferralInfo info) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: info.shareMessage));
    if (!mounted) return;
    showMessage(context, l10n.referralShareCopied);
    // Best effort: analytics never holds up or breaks Share.
    unawaited(
      ref
          .read(analyticsProvider)
          .logEvent(
            'share',
            parameters: const {
              'method': 'clipboard',
              'content_type': 'referral_code',
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final referral = ref.watch(currentReferralProvider);
    ref.listen(currentReferralProvider, (previous, next) {
      if (isFailedRefresh(previous, next)) showRefreshFailed(context, _reload);
    });
    // Also when a reload failed: keep the last answer on screen (CA-03).
    final info = referral.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.referralTitle)),
      body: switch (referral) {
        AsyncData() || AsyncError() when info != null => RefreshIndicator(
          onRefresh: _pullToRefresh,
          child: _ReferralBody(
            info: info,
            codeController: _code,
            onCopy: () => _copyCode(info),
            onShare: () => _share(info),
            onApply: _apply,
          ),
        ),
        AsyncError(:final error) => ErrorRetryView(
          error: error,
          onRetry: _reload,
        ),
        _ => const SkeletonList(rows: 4),
      },
    );
  }
}

class _ReferralBody extends ConsumerWidget {
  const _ReferralBody({
    required this.info,
    required this.codeController,
    required this.onCopy,
    required this.onShare,
    required this.onApply,
  });

  final ReferralInfo info;
  final TextEditingController codeController;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final referredBy = info.referredBy;
    final minOrder = isZeroAmount(info.rewardMinOrderValue)
        ? null
        : formatRupeesOrNull(info.rewardMinOrderValue);

    return ListView(
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        if (info.isEnabled) ...[
          _Hero(text: referralHeadlineText(l10n, info)),
          const SizedBox(height: JivoSpacing.lg),
          _CodeBox(code: info.code, onCopy: onCopy),
          const SizedBox(height: JivoSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('referral-share'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined),
              label: Text(l10n.referralShare),
            ),
          ),
        ] else
          _Notice(
            key: const Key('referral-paused'),
            icon: Icons.pause_circle_outline,
            text: l10n.referralPaused,
          ),
        if (info.canApplyCode) ...[
          const SizedBox(height: JivoSpacing.xl),
          _ApplyCodeBox(controller: codeController, onApply: onApply),
        ],
        if (referredBy != null) ...[
          const SizedBox(height: JivoSpacing.xl),
          _JoinedWithCard(referredBy: referredBy, info: info),
        ],
        const SizedBox(height: JivoSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            l10n.referralHowItWorks,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: JivoSpacing.md),
        _Step(number: 1, text: l10n.referralStep1),
        _Step(number: 2, text: l10n.referralStep2),
        _Step(
          number: 3,
          text: [
            referralStep3Text(l10n, info),
            if (minOrder != null) l10n.referralMinOrder(minOrder),
          ].join(' '),
        ),
        const SizedBox(height: JivoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _Stat(
                key: const Key('referral-friends-joined'),
                value: info.friendsJoined,
                label: l10n.referralFriendsJoined,
              ),
            ),
            const SizedBox(width: JivoSpacing.md),
            Expanded(
              child: _Stat(
                key: const Key('referral-rewards-earned'),
                value: info.friendsRewarded,
                label: l10n.referralRewardsEarned,
              ),
            ),
          ],
        ),
        if (info.friendsJoined == 0 && info.isEnabled) ...[
          const SizedBox(height: JivoSpacing.md),
          Text(
            l10n.referralNoFriendsYet,
            key: const Key('referral-no-friends'),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: JivoSpacing.xl),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(JivoSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(JivoRadii.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.card_giftcard, size: 40, color: scheme.onPrimaryContainer),
          const SizedBox(width: JivoSpacing.lg),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        JivoSpacing.lg,
        JivoSpacing.md,
        JivoSpacing.sm,
        JivoSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
        borderRadius: BorderRadius.circular(JivoRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: l10n.referralCodeSemantics(code),
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.referralYourCode, style: theme.textTheme.bodySmall),
                  const SizedBox(height: JivoSpacing.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      code,
                      key: const Key('referral-code'),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            key: const Key('referral-copy'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onCopy,
            icon: const Icon(Icons.copy, size: 20),
            label: Text(
              l10n.referralCopy,
              semanticsLabel: l10n.referralCopyCodeSemantics,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyCodeBox extends ConsumerWidget {
  const _ApplyCodeBox({required this.controller, required this.onApply});

  final TextEditingController controller;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(referralApplyProvider);
    final error = state.missingCode
        ? l10n.referralCodeRequired
        : state.error == null
        ? null
        : describeErrorWithDetails(context, state.error!);

    return Card(
      key: const Key('referral-apply-box'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.referralHaveCode,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: JivoSpacing.xs),
            Text(l10n.referralHaveCodeHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: JivoSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: ReferralScreen.codeFieldKey,
                    controller: controller,
                    enabled: !state.busy,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 32,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) =>
                        ref.read(referralApplyProvider.notifier).clearError(),
                    onSubmitted: (_) => onApply(),
                    decoration: InputDecoration(
                      labelText: l10n.referralCodeLabel,
                      counterText: '',
                      errorText: error,
                      errorMaxLines: 3,
                    ),
                  ),
                ),
                const SizedBox(width: JivoSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: JivoSpacing.xs),
                  child: FilledButton(
                    key: ReferralScreen.applyKey,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: state.busy ? null : onApply,
                    child: state.busy
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: l10n.referralApply,
                            ),
                          )
                        : Text(l10n.referralApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinedWithCard extends StatelessWidget {
  const _JoinedWithCard({required this.referredBy, required this.info});

  final ReferredBy referredBy;
  final ReferralInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = referralStatusText(l10n, info, referredBy.status);
    return _Notice(
      key: const Key('referral-joined'),
      icon: referredBy.status == ReferralStatus.rewarded
          ? Icons.check_circle_outline
          : Icons.how_to_reg_outlined,
      title: l10n.referralJoinedWith(referredBy.codeMasked),
      text: status,
    );
  }
}

/// An icon with a bold [title] and/or a [text] line, in a tinted box.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, this.title, this.text, super.key});

  final IconData icon;
  final String? title;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(JivoSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(JivoRadii.md),
      ),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: JivoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (title != null && text != null)
                    const SizedBox(height: JivoSpacing.xs),
                  if (text != null) Text(text!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: JivoSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 12,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: JivoSpacing.md),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, super.key});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(JivoSpacing.lg),
        child: MergeSemantics(
          child: Column(
            children: [
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: JivoSpacing.xs),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
