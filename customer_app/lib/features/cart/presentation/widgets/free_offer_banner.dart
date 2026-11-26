import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/cart.dart';

/// The cart's free-carton banner ("buy 10 get 1 free", ADR 0002/0003): the
/// first card in the cart, in the bold gold offer colours so it is seen
/// first.
///
/// - Nothing earned yet: the server's nudge ([nudge], e.g. "Add 5 more
///   cartons to get 1 free") is the headline.
/// - Free cartons earned (`free_offer.free_units` > 0): "You get 2 free
///   cartons with this order!" is the headline and the nudge for the next
///   one is under it.
/// - With a fixed free size (`free_offer.free_variant`, ADR 0003): "Free
///   carton size: Jivo Water 1 L × 12" as the last line.
///
/// Every number and text is the server's: nothing is counted here.
/// Text is `onGold` (#3B2600) on the gold gradient (#FFE9A8 → #FFC24D):
/// 8.9:1 or more, well above WCAG AA.
class FreeOfferBanner extends StatelessWidget {
  const FreeOfferBanner({required this.offer, this.nudge, super.key});

  final FreeOffer offer;

  /// The server's `free_offer.message` (or the app's sentence from
  /// `units_to_next_free` when it sends none); null when there is none.
  final String? nudge;

  /// Whether the banner has anything to say for [offer] and [nudge].
  static bool shows(FreeOffer? offer, String? nudge) =>
      offer != null && (offer.freeUnits > 0 || nudge != null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.customerColors;
    final ink = colors.onGold;
    final earned = offer.freeUnits;
    final headline = earned > 0 ? l10n.freeOfferEarned(earned) : nudge;
    if (headline == null) return const SizedBox.shrink();
    final detail = earned > 0 ? nudge : null;
    final size = offer.freeVariant;
    final sizeName = size == null
        ? null
        : [
            size.productName.trim(),
            size.name.trim(),
          ].where((part) => part.isNotEmpty).join(' ');

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors.offerGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(JivoRadii.md),
          border: Border.all(color: colors.goldEdge.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: colors.softShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(JivoSpacing.md),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    earned > 0 ? Icons.redeem : Icons.card_giftcard,
                    key: const Key('free-offer-icon'),
                    color: ink,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: JivoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      key: Key(
                        earned > 0 ? 'free-offer-earned' : 'free-offer-message',
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        key: const Key('free-offer-message'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (sizeName != null && sizeName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.freeOfferSizeHint(sizeName),
                        key: const Key('free-offer-size'),
                        style: theme.textTheme.bodySmall?.copyWith(color: ink),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
