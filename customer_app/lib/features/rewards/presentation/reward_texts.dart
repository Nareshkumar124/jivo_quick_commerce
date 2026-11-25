import '../../../l10n/generated/app_localizations.dart';
import '../../cart/domain/cart.dart';
import '../domain/reward.dart';

/// The one place that turns the rewards API's codes into text (rule 4).

/// "Welcome gift" / "Referral reward"; null for an ordinary coupon or a
/// source this build doesn't know.
String? rewardSourceText(AppLocalizations l10n, RewardSource source) =>
    switch (source) {
      RewardSource.welcome => l10n.rewardSourceWelcome,
      RewardSource.referralReferrer ||
      RewardSource.referralReferred => l10n.rewardSourceReferral,
      RewardSource.none || RewardSource.unknown => null,
    };

/// The status chip: "Available" or "Claimed" (used and expired rewards
/// are only in the history).
String rewardStatusText(AppLocalizations l10n, RewardStatus status) =>
    switch (status) {
      RewardStatus.claimed => l10n.rewardStatusClaimed,
      RewardStatus.used => l10n.rewardHistoryUsed,
      RewardStatus.expired => l10n.rewardHistoryExpired,
      RewardStatus.available ||
      RewardStatus.unknown => l10n.rewardStatusAvailable,
    };

/// A history row's kind; null for a kind this build doesn't know (the
/// server's title is shown alone then).
String? rewardHistoryKindText(AppLocalizations l10n, RewardHistoryKind kind) =>
    switch (kind) {
      RewardHistoryKind.earned => l10n.rewardHistoryEarned,
      RewardHistoryKind.claimed => l10n.rewardHistoryClaimed,
      RewardHistoryKind.used => l10n.rewardHistoryUsed,
      RewardHistoryKind.expired => l10n.rewardHistoryExpired,
      RewardHistoryKind.volumeFree => l10n.rewardHistoryVolumeFree,
      RewardHistoryKind.unknown => null,
    };
