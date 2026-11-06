import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../app/repositories.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final total = snapshot.itemTotal;
    final summary = [
      l10n.cartItems(snapshot.itemCount),
      ?formatRupeesOrNull(total),
    ].join(' · ');

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
          color: scheme.primary,
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
                child: Row(
                  children: [
                    Icon(Icons.shopping_bag_outlined, color: scheme.onPrimary),
                    const SizedBox(width: JivoSpacing.md),
                    Expanded(
                      child: Text(
                        summary,
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      l10n.viewCart,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onPrimary),
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
