import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/rider_task.dart';
import '../domain/task_rules.dart';

/// "Amount changed: collect ₹990" / "Was ₹1,240. ..." (UX audit RD-03,
/// `design/screens/rider/cod.md` §3). No close button: it stays for the whole
/// task: the store
/// changed the order after the offer (08 T8a), so the rider does not ask the
/// customer for the amount they remember from the offer. Both values are
/// the server's. Renders nothing when the amount did not change.
class CodAmountChangedNotice extends StatelessWidget {
  const CodAmountChangedNotice({required this.task, super.key});

  final RiderTask task;

  @override
  Widget build(BuildContext context) {
    final was = codAmountWasText(task);
    final now = codAmountText(task);
    if (was == null || now == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('cod-amount-changed'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: riderCodDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, size: 28, color: RiderColors.of(context).codBorder),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.codAmountChangedTitle(now),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: RiderColors.of(context).codText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.codAmountChangedBody(was),
                  style: TextStyle(
                    fontSize: 16,
                    color: RiderColors.of(context).codText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
