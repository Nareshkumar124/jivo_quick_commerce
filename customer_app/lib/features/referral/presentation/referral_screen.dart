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

/// The server's reward amount for display, e.g. `₹90`.
String referralRewardText(ReferralInfo info) =>
    formatRupeesOrNull(info.rewardAmount) ?? info.rewardAmount;

/// Account row that opens the referral screen. Names the reward once it is
/// known, and invites a new customer to enter a friend's code.
class ReferralAccountTile extends ConsumerWidget {
  const ReferralAccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final info = ref.watch(currentReferralProvider).value;
    final reward = info == null ? null : formatRupeesOrNull(info.rewardAmount);
    final active = info != null && info.isEnabled && reward != null;
    return ListTile(
      key: const Key('account-referral'),
      leading: const Icon(Icons.card_giftcard_outlined),
      title: Text(active ? l10n.referAndEarn(reward) : l10n.referAFriend),
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
    if (info != null) {
      showMessage(context, l10n.referralApplied(referralRewardText(info)));
    }
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
    final reward = referralRewardText(info);
    final referredBy = info.referredBy;
    final minOrder = isZeroAmount(info.rewardMinOrderValue)
        ? null
        : formatRupeesOrNull(info.rewardMinOrderValue);

    return ListView(
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        if (info.isEnabled) ...[
          _Hero(text: l10n.referralHeadline(reward)),
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
          _JoinedWithCard(referredBy: referredBy, reward: reward),
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
            l10n.referralStep3(reward, info.rewardValidityDays),
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
  const _JoinedWithCard({required this.referredBy, required this.reward});

  final ReferredBy referredBy;
  final String reward;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = switch (referredBy.status) {
      ReferralStatus.pending => l10n.referralStatusPending(reward),
      ReferralStatus.rewarded => l10n.referralStatusRewarded(reward),
      ReferralStatus.noReward => l10n.referralStatusNoReward,
      ReferralStatus.unknown => null,
    };
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
