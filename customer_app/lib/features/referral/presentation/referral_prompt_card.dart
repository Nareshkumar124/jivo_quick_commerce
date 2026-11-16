import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'referral_controller.dart';
import 'referral_screen.dart';

/// "Have a referral code?" at checkout, for a customer who can still enter
/// one (the server's `can_apply_code`: program on, no code yet, no order
/// placed). Closable; hidden while loading or on error. "Enter code" opens
/// the referral screen.
class ReferralPromptCard extends ConsumerWidget {
  const ReferralPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(currentReferralProvider).value;
    final dismissed = ref.watch(referralPromptDismissedProvider);
    if (info == null || !info.isEnabled || !info.canApplyCode || dismissed) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: JivoSpacing.lg),
      child: Card(
        key: const Key('referral-prompt'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            JivoSpacing.lg,
            JivoSpacing.sm,
            JivoSpacing.xs,
            JivoSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: JivoSpacing.md),
                child: Icon(
                  Icons.card_giftcard_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: JivoSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: JivoSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.referralHaveCode,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: JivoSpacing.xs),
                      Text(
                        l10n.referralPromptBody(referralRewardText(info)),
                        style: theme.textTheme.bodySmall,
                      ),
                      TextButton(
                        key: const Key('referral-prompt-enter'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => context.push(Routes.referral),
                        child: Text(l10n.referralPromptAction),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                key: const Key('referral-prompt-close'),
                tooltip: l10n.referralPromptDismiss,
                icon: const Icon(Icons.close),
                onPressed: () => ref
                    .read(referralPromptDismissedProvider.notifier)
                    .dismiss(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
