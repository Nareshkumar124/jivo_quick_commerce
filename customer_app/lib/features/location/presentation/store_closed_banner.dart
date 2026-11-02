import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../domain/delivery_location.dart';

/// "Store opens at 7:00 AM": browsing stays on, checkout is off
/// (`03 §2.3`).
class StoreClosedBanner extends StatelessWidget {
  const StoreClosedBanner({required this.store, super.key});

  final StoreInfo store;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.jivoColors;
    final opensAt = store.opensAt;
    return Material(
      key: const Key('store-closed-banner'),
      color: colors.warning,
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: JivoSpacing.gutter,
            vertical: JivoSpacing.md,
          ),
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, color: colors.onWarning),
              const SizedBox(width: JivoSpacing.md),
              Expanded(
                child: Text(
                  storeClosedText(l10n, opensAt, now: DateTime.now()),
                  style: TextStyle(color: colors.onWarning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Opens at 7:00 am" today, "Opens tomorrow at 7:00 am", otherwise the
/// date and time; all in IST.
String storeClosedText(
  AppLocalizations l10n,
  DateTime? opensAt, {
  required DateTime now,
}) {
  if (opensAt == null) return l10n.storeClosed;
  final open = toIst(opensAt);
  final today = toIst(now);
  final days = DateTime.utc(
    open.year,
    open.month,
    open.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return switch (days) {
    <= 0 => l10n.storeClosedOpensAt(formatTime(opensAt)),
    1 => l10n.storeClosedOpensTomorrow(formatTime(opensAt)),
    _ => l10n.storeClosedOpensAt(formatDateTime(opensAt)),
  };
}
