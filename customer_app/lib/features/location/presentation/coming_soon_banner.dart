import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// "We're coming to your area soon!" for a location Jivo doesn't deliver
/// to yet: the home's not-serviceable state and the not-serviceable screen.
/// A deep-green card with a gold scooter badge, the headline and, under
/// it, the server's [message] (the serviceability `message`, managed from
/// the admin with the delivery areas), or a general line when it sends
/// none. No area is written into the app. The caller adds its own buttons
/// (Change location, Notify me) under it.
///
/// Text is white on the header green (#1F3F1C → #2D5528): 8.6:1 or more.
class ComingSoonBanner extends StatelessWidget {
  const ComingSoonBanner({this.message, super.key});

  /// The server's text for this location; null or blank: the l10n
  /// fallback.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final serverText = message?.trim();
    final body = serverText == null || serverText.isEmpty
        ? l10n.comingSoonBody
        : serverText;
    final theme = Theme.of(context);
    final colors = context.customerColors;
    final onGreen = theme.colorScheme.onPrimary;

    return DecoratedBox(
      key: const Key('coming-soon-banner'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(JivoRadii.lg),
        boxShadow: [
          BoxShadow(
            color: colors.softShadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(JivoRadii.lg),
        child: Stack(
          // Full width: the card, not its text, sets the size.
          alignment: Alignment.center,
          children: [
            const SizedBox(width: double.infinity),
            // A large faint pin in the corner: decoration only.
            PositionedDirectional(
              end: -24,
              top: -16,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.location_on,
                  size: 140,
                  color: onGreen.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(JivoSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: onGreen.withValues(alpha: 0.6),
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.delivery_dining,
                        size: 44,
                        color: colors.onGold,
                      ),
                    ),
                  ),
                  const SizedBox(height: JivoSpacing.lg),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.comingSoonTitle,
                      key: const Key('coming-soon-title'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: JivoSpacing.sm),
                  Text(
                    body,
                    key: const Key('coming-soon-body'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onGreen,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
