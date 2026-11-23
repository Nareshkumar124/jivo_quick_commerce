import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../app/theme.dart';
import 'cart_controller.dart';

/// The floating cart bar: "2 items · ₹348 · View cart" (`03 §1`). Hidden
/// while the cart is empty. The amount is the server's item total, shown
/// only when the server sends it; the app never adds prices up.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cartAvailableProvider)) return const SizedBox.shrink();
    final snapshot = ref.watch(cartProvider.select((c) => c.snapshot));
    if (snapshot.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final cc = context.customerColors;
    final total = snapshot.itemTotal;
    final summary = [
      l10n.cartItems(snapshot.itemCount),
      ?formatRupeesOrNull(total),
    ].join(' · ');

    // From 1.5x text the summary and "View cart" no longer fit on one
    // line on a 360 dp phone: the pill moves under the summary.
    final stacked = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.5;
    const icon = Icon(Icons.shopping_bag_rounded, color: Colors.white);
    const gap = SizedBox(width: JivoSpacing.md);
    final summaryText = Expanded(
      child: Text(
        summary,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Colors.white),
      ),
    );
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(JivoRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.viewCart,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          JivoSpacing.gutter,
          JivoSpacing.sm,
          JivoSpacing.gutter,
          JivoSpacing.sm,
        ),
        child: Material(
          key: const Key('cart-bar'),
          // Home redesign: Jivo green with a white pill (was deep green and
          // gold).
          color: Theme.of(context).colorScheme.primary,
          elevation: 2,
          shadowColor: cc.softShadow,
          borderRadius: BorderRadius.circular(JivoRadii.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(JivoRadii.md),
            onTap: () => context.push(Routes.cart),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: JivoSpacing.lg,
                  vertical: JivoSpacing.sm,
                ),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [icon, gap, summaryText]),
                          const SizedBox(height: JivoSpacing.sm),
                          Align(alignment: Alignment.centerRight, child: pill),
                        ],
                      )
                    : Row(
                        children: [
                          icon,
                          gap,
                          summaryText,
                          const SizedBox(width: JivoSpacing.sm),
                          pill,
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
