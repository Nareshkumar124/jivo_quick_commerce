import 'package:flutter/material.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/formatting/formatters.dart';
import '../../domain/catalog_models.dart';

/// One row of the wholesale rate table: [from] to [to] boxes in the order
/// ([to] null = "and more") at the server's [price].
typedef PriceTierRow = ({int from, int? to, String price});

/// The server's `price_tiers` as table rows, lowest first. Each range ends
/// one below the next tier's minimum; the last one is open ("250+"). Only
/// box counts are derived here; every price is the server's string.
List<PriceTierRow> priceTierRows(List<PriceTier> tiers) {
  final sorted = [...tiers]
    ..sort((a, b) => a.minOrderUnits.compareTo(b.minOrderUnits));
  final rows = <PriceTierRow>[];
  for (var i = 0; i < sorted.length; i++) {
    final from = sorted[i].minOrderUnits;
    final to = i + 1 < sorted.length ? sorted[i + 1].minOrderUnits - 1 : null;
    // Two tiers with the same minimum: the later one covers it.
    if (to != null && to < from) continue;
    rows.add((from: from, to: to, price: sorted[i].price));
  }
  return rows;
}

/// "5–24 boxes", "7 boxes" or "250+ boxes".
String priceTierRangeText(AppLocalizations l10n, PriceTierRow row) =>
    switch (row.to) {
      null => l10n.priceTierFrom(row.from),
      final to when to == row.from => l10n.priceTierExactly(to),
      final to => l10n.priceTierRange(row.from, to),
    };

/// The wholesale (volume) rate table on the product page (`price_tiers`,
/// ADR 0001): "5–24 boxes ₹90" … "250+ boxes ₹80", then a note that every
/// size counts towards the total. Nothing when the variant has no tiers.
class PriceTiersTable extends StatelessWidget {
  const PriceTiersTable({required this.tiers, super.key});

  final List<PriceTier> tiers;

  @override
  Widget build(BuildContext context) {
    final rows = priceTierRows(tiers);
    if (rows.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      key: const Key('price-tiers'),
      width: double.infinity,
      padding: const EdgeInsets.all(JivoSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.wholesaleRatesTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: JivoSpacing.xs),
          for (final row in rows) _TierRowView(row: row),
          const SizedBox(height: JivoSpacing.xs),
          Text(
            l10n.priceTierNote,
            key: const Key('price-tiers-note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierRowView extends StatelessWidget {
  const _TierRowView({required this.row});

  final PriceTierRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final range = priceTierRangeText(l10n, row);
    final price = displayRupees(row.price);
    return Semantics(
      label: l10n.priceTierRowSemantics(range, price),
      excludeSemantics: true,
      child: Padding(
        key: ValueKey('price-tier-${row.from}'),
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(range)),
            const SizedBox(width: JivoSpacing.sm),
            Text(
              price,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The same rates in the variant picker, compact: a label and small
/// chips ("5–24: ₹90", "250+: ₹80"). Nothing when there are no tiers.
class PriceTiersCompact extends StatelessWidget {
  const PriceTiersCompact({required this.tiers, super.key});

  final List<PriceTier> tiers;

  @override
  Widget build(BuildContext context) {
    final rows = priceTierRows(tiers);
    if (rows.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chipStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.wholesaleRatesTitle,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: JivoSpacing.xs),
        Wrap(
          spacing: JivoSpacing.xs,
          runSpacing: JivoSpacing.xs,
          children: [
            for (final row in rows)
              Semantics(
                label: l10n.priceTierRowSemantics(
                  priceTierRangeText(l10n, row),
                  displayRupees(row.price),
                ),
                excludeSemantics: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(JivoRadii.sm / 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      l10n.priceTierChip(switch (row.to) {
                        null => l10n.priceTierFromShort(row.from),
                        final to when to == row.from => '$to',
                        final to => l10n.priceTierRangeShort(row.from, to),
                      }, displayRupees(row.price)),
                      style: chipStyle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
