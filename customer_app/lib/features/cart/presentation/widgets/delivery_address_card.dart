import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../location/presentation/delivery_controller.dart';
import '../../../location/presentation/location_options.dart';

/// The delivery address on the cart and checkout (`03 §2.8`). Change opens
/// the address switcher, which re-runs serviceability (and asks before
/// clearing the cart when the store changes).
///
/// Orders need a saved address (`POST /orders/ {address_id}`), so a pinned
/// or detected location without one shows a prompt to choose one.
class DeliveryAddressCard extends ConsumerWidget {
  const DeliveryAddressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final location = ref.watch(deliveryProvider.select((s) => s.location));
    final needsAddress = location?.addressId == null;

    return Card(
      key: const Key('delivery-address-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          JivoSpacing.lg,
          JivoSpacing.md,
          JivoSpacing.sm,
          JivoSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: JivoSpacing.xs),
              child: Icon(
                Icons.location_on_outlined,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: JivoSpacing.md),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.deliverTo,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (location != null)
                      Text(
                        location.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (location?.subtitle case final subtitle?)
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    if (needsAddress)
                      Padding(
                        padding: const EdgeInsets.only(top: JivoSpacing.xs),
                        child: Text(
                          l10n.chooseSavedAddress,
                          key: const Key('needs-saved-address'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            TextButton(
              key: const Key('change-address'),
              onPressed: () => showAddressSwitcher(context),
              child: Text(
                needsAddress ? l10n.selectAddress : l10n.changeAddress,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
