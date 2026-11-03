import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/skeletons.dart';
import '../../../shared/widgets/state_views.dart';
import '../../location/presentation/delivery_controller.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';
import 'widgets/bill_details.dart';
import 'widgets/cart_line_tile.dart';
import 'widgets/coupon_sheet.dart';
import 'widgets/delivery_address_card.dart';
import 'widgets/instructions_selector.dart';
import 'widgets/tip_selector.dart';

/// The cart (`03 §2.8`, screen #20). It reloads on open (stock
/// re-validation) and renders the server's lines and bill as sent.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _proceeding = false;

  int? get _addressId =>
      ref.read(deliveryProvider.select((s) => s.location?.addressId));

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() =>
      ref.read(cartProvider.notifier).refresh(addressId: _addressId);

  /// Re-validates stock and the bill, then opens checkout (`03 §2.8`).
  Future<void> _proceed() async {
    if (_proceeding) return;
    setState(() => _proceeding = true);
    await _refresh();
    if (!mounted) return;
    setState(() => _proceeding = false);
    final cart = ref.read(cartProvider);
    final error = cart.loadError;
    if (cart.load == CartLoad.failed && error != null) {
      showMessage(context, describeErrorWithDetails(context, error));
    } else if (cart.snapshot.hasProblems) {
      showMessage(context, AppLocalizations.of(context).cartReviewChanges);
    } else if (!cart.snapshot.isEmpty &&
        (cart.snapshot.minimumOrder?.met ?? true)) {
      await context.push(Routes.checkout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cart = ref.watch(cartProvider);
    final snapshot = cart.snapshot;
    // A new address re-prices the bill.
    ref.listen(deliveryProvider.select((s) => s.location?.addressId), (
      previous,
      next,
    ) {
      if (previous != next) {
        ref.read(cartProvider.notifier).refresh(addressId: next);
      }
    });

    final Widget body;
    if (snapshot.isEmpty) {
      body = switch (cart.load) {
        CartLoad.idle || CartLoad.loading => const _CartSkeleton(),
        CartLoad.failed => ErrorRetryView(
          error: cart.loadError ?? const ApiError(code: ApiErrorCode.unknown),
          onRetry: _refresh,
        ),
        CartLoad.ready => EmptyView(
          key: const Key('cart-empty'),
          message: l10n.cartEmpty,
          icon: Icons.shopping_bag_outlined,
          action: FilledButton(
            onPressed: () => context.go(Routes.home),
            child: Text(l10n.startShopping),
          ),
        ),
      };
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: _CartContent(cart: cart),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartTitle)),
      body: body,
      bottomNavigationBar: snapshot.isEmpty || snapshot.bill == null
          ? null
          : _CheckoutBar(
              snapshot: snapshot,
              busy: cart.busy || _proceeding,
              proceeding: _proceeding,
              onProceed: _proceed,
            ),
    );
  }
}

class _CartContent extends StatelessWidget {
  const _CartContent({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snapshot = cart.snapshot;
    final bill = snapshot.bill;
    final nudge = bill?.freeDeliveryShortfall;
    final loadError = cart.loadError;
    const gap = SizedBox(height: JivoSpacing.lg);

    return ListView(
      key: const Key('cart-content'),
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        if (cart.load == CartLoad.failed && loadError != null) ...[
          _Notice(
            key: const Key('cart-refresh-failed'),
            icon: Icons.cloud_off_outlined,
            text: describeErrorWithDetails(context, loadError),
            color: theme.colorScheme.error,
          ),
          gap,
        ],
        if (snapshot.hasProblems) ...[
          _Notice(
            key: const Key('cart-problems'),
            icon: Icons.warning_amber_outlined,
            text: l10n.cartProblemsBanner,
            color: theme.colorScheme.error,
          ),
          gap,
        ],
        const DeliveryAddressCard(),
        gap,
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: JivoSpacing.md,
              vertical: JivoSpacing.xs,
            ),
            child: Column(
              children: [
                for (final line in snapshot.lines)
                  CartLineTile(key: ValueKey(line.id), line: line),
              ],
            ),
          ),
        ),
        if (nudge != null && !isZeroAmount(nudge)) ...[
          const SizedBox(height: JivoSpacing.md),
          _Notice(
            key: const Key('free-delivery-nudge'),
            icon: Icons.local_shipping_outlined,
            text: l10n.freeDeliveryNudge(formatRupees(nudge)),
            color: context.jivoColors.success,
          ),
        ],
        gap,
        _CouponRow(coupon: snapshot.coupon),
        gap,
        const TipSelector(),
        gap,
        const InstructionsSelector(),
        if (bill != null) ...[
          gap,
          BillDetails(bill: bill, coupon: snapshot.coupon),
        ],
        gap,
      ],
    );
  }
}

/// "Apply coupon", or the applied coupon with its saving and Remove.
class _CouponRow extends ConsumerWidget {
  const _CouponRow({required this.coupon});

  final AppliedCoupon? coupon;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cartProvider.notifier).removeCoupon();
    } catch (error) {
      if (context.mounted) {
        showMessage(context, describeErrorWithDetails(context, error));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(cartProvider.select((c) => c.updating));
    final applied = coupon;
    if (applied == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          key: const Key('apply-coupon'),
          minTileHeight: kJivoMinTouchTarget,
          leading: Icon(
            Icons.local_offer_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(l10n.applyCoupon),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showCouponSheet(context),
        ),
      );
    }
    final problem = applied.problem;
    return Card(
      key: const Key('applied-coupon'),
      margin: EdgeInsets.zero,
      child: ListTile(
        minTileHeight: kJivoMinTouchTarget,
        leading: Icon(
          problem == null ? Icons.check_circle : Icons.error_outline,
          color: problem == null
              ? context.jivoColors.success
              : theme.colorScheme.error,
        ),
        title: Text(
          problem == null
              ? l10n.couponApplied(applied.code)
              : l10n.couponNoLongerApplies(applied.code),
        ),
        subtitle: problem == null
            ? Text(l10n.couponSaves(formatRupees(applied.discount)))
            : Text(couponProblemText(l10n, problem)),
        onTap: () => showCouponSheet(context),
        trailing: TextButton(
          key: const Key('remove-coupon'),
          onPressed: busy ? null : () => _remove(context, ref),
          child: Text(l10n.removeAction),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(JivoSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(JivoRadii.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: JivoSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "To pay ₹X" and Proceed. Disabled below the minimum order (server's
/// judgement), while the store is closed, while lines are flagged, and
/// while a change to the bill is in flight.
class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar({
    required this.snapshot,
    required this.busy,
    required this.proceeding,
    required this.onProceed,
  });

  final CartSnapshot snapshot;
  final bool busy;
  final bool proceeding;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final storeClosed = ref.watch(
      deliveryProvider.select((s) => s.serviceability?.storeClosed ?? false),
    );
    final blocked = storeClosed
        ? l10n.cartStoreClosed
        : switch (snapshot.minimumOrder) {
            MinimumOrder(
              met: false,
              :final amount,
              shortfall: final shortfall?,
            ) =>
              l10n.minimumOrderShortfall(
                formatRupees(amount),
                formatRupees(shortfall),
              ),
            MinimumOrder(met: false, :final amount) => l10n.minimumOrderNotMet(
              formatRupees(amount),
            ),
            _ when snapshot.hasProblems => l10n.cartProblemsBanner,
            _ => null,
          };

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(JivoSpacing.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blocked != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
                  child: Text(
                    blocked,
                    key: const Key('checkout-blocked'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              Row(
                children: [
                  MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.billToPay,
                          style: theme.textTheme.labelMedium,
                        ),
                        Text(
                          formatRupees(snapshot.bill!.grandTotal),
                          key: const Key('checkout-bar-total'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: JivoSpacing.lg),
                  Expanded(
                    child: BusyButton(
                      key: const Key('proceed-to-checkout'),
                      label: l10n.proceedToCheckout,
                      busy: proceeding,
                      onPressed: blocked != null || busy ? null : onProceed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSkeleton extends StatelessWidget {
  const _CartSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonSemantics(
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(JivoSpacing.gutter),
      children: [
        const SkeletonBox(height: 72, width: double.infinity),
        const SizedBox(height: JivoSpacing.lg),
        for (var i = 0; i < 3; i++) ...[
          const Row(
            children: [
              SkeletonBox(width: 56, height: 56),
              SizedBox(width: JivoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 14, width: double.infinity),
                    SizedBox(height: JivoSpacing.xs),
                    SkeletonBox(height: 14, width: 120),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: JivoSpacing.lg),
        ],
        const SkeletonBox(height: 160, width: double.infinity),
      ],
    ),
  );
}
