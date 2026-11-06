import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/cart_texts.dart';
import '../../cart/presentation/widgets/bill_details.dart';
import '../../cart/presentation/widgets/delivery_address_card.dart';
import '../../location/presentation/delivery_controller.dart';
import '../../orders/domain/order.dart';
import '../domain/checkout_result.dart';
import 'checkout_controller.dart';
import 'payment_failed_screen.dart';

/// Payment method and Place order (`03 §2.9`, screen #22).
///
/// Cash on Delivery is offered only when the server says the cart is
/// eligible. The button is disabled while the order is placed and paid
/// (double-tap protection), and Back is blocked until the flow ends.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final checkout = ref.watch(checkoutProvider);
    final controller = ref.read(checkoutProvider.notifier);
    final snapshot = ref.watch(cartProvider.select((c) => c.snapshot));
    final location = ref.watch(deliveryProvider.select((s) => s.location));

    ref
      ..listen(checkoutProvider.select((s) => s.result), (_, result) {
        if (result == null) return;
        controller.acknowledge();
        switch (result) {
          case OrderConfirmed(:final order):
            context.go(Routes.orderSuccess(order.id), extra: order);
          case PaymentIncomplete(:final order, :final reason, :final error):
            context.go(
              Routes.paymentFailed(order.id),
              extra: PaymentFailedArgs(
                order: order,
                reason: reason,
                error: error,
              ),
            );
        }
      })
      ..listen(checkoutProvider.select((s) => s.error), (_, error) {
        if (error == null) return;
        final online = ref.read(checkoutProvider).method == PaymentMethod.online;
        controller.acknowledge();
        // M6: the payment gateway is down at placement. The server created
        // the order and ended it PAYMENT_FAILED (it shows in My orders);
        // the cart is kept, so the customer can retry or pick COD.
        if (online && error.code == ApiErrorCode.serviceUnavailable) {
          showMessage(
            context,
            AppLocalizations.of(context).onlinePaymentUnavailable,
          );
          return;
        }
        // What changed, from the error's details; the cart was reloaded.
        showMessage(context, cartErrorText(context, error, cart: snapshot));
        // Flagged lines are fixed on the cart screen.
        if (error.code == ApiErrorCode.stockUnavailable && context.canPop()) {
          context.pop();
        }
      })
      ..listen(checkoutProvider.select((s) => s.pendingOrderId), (_, id) {
        if (id == null) return;
        controller.acknowledge();
        _showPendingOrder(context, id);
      });

    final bill = snapshot.bill;
    if (snapshot.isEmpty || bill == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
        body: EmptyView(
          message: l10n.cartEmpty,
          icon: Icons.shopping_bag_outlined,
          action: FilledButton(
            onPressed: () => context.go(Routes.home),
            child: Text(l10n.startShopping),
          ),
        ),
      );
    }

    // Only the methods the server offers for this cart (`payment_methods`;
    // COD only when eligible, `03 §2.9`).
    final offered = [
      for (final m in PaymentMethod.values)
        if (snapshot.offers(m)) m,
    ];
    final method = offered.contains(checkout.method)
        ? checkout.method
        : (offered.isEmpty ? checkout.method : offered.first);
    final addressId = location?.addressId;
    // The server decides (`Cart.checkout`); the order also needs a saved
    // address id and an offered method.
    // A total that can't be shown can't be paid (RD-02).
    final grandTotal = formatRupeesOrNull(bill.grandTotal);
    final canPlace =
        !checkout.busy &&
        grandTotal != null &&
        addressId != null &&
        snapshot.checkout.canPlaceOrder &&
        offered.contains(method);
    final blocker = snapshot.checkout.canPlaceOrder
        ? null
        : checkoutBlockerText(l10n, snapshot);
    final progress = switch (checkout.step) {
      CheckoutStep.idle => null,
      CheckoutStep.placing => l10n.checkoutPlacing,
      CheckoutStep.paying => l10n.checkoutPaying,
      CheckoutStep.verifying => l10n.checkoutVerifying,
    };

    return PopScope(
      canPop: !checkout.busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutTitle)),
        body: ListView(
          padding: const EdgeInsets.all(JivoSpacing.gutter),
          children: [
            const DeliveryAddressCard(),
            const SizedBox(height: JivoSpacing.lg),
            Semantics(
              header: true,
              child: Text(l10n.payWith, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: JivoSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              child: RadioGroup<PaymentMethod>(
                groupValue: method,
                onChanged: (value) {
                  if (value != null && !checkout.busy) {
                    controller.selectMethod(value);
                  }
                },
                child: Column(
                  children: [
                    if (snapshot.offers(PaymentMethod.online))
                      RadioListTile<PaymentMethod>(
                        key: const Key('pay-online'),
                        value: PaymentMethod.online,
                        enabled: !checkout.busy,
                        secondary: const Icon(Icons.account_balance_outlined),
                        title: Text(l10n.payOnline),
                        subtitle: Text(l10n.payOnlineSubtitle),
                      ),
                    if (snapshot.offers(PaymentMethod.cod))
                      RadioListTile<PaymentMethod>(
                        key: const Key('pay-cod'),
                        value: PaymentMethod.cod,
                        enabled: !checkout.busy,
                        secondary: const Icon(Icons.payments_outlined),
                        title: Text(l10n.payCod),
                        subtitle: Text(l10n.payCodSubtitle),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: JivoSpacing.lg),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(JivoSpacing.lg),
                child: BillDetails(bill: bill, coupon: snapshot.coupon),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Material(
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
                  if (blocker != null && !checkout.busy)
                    Padding(
                      padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
                      child: Text(
                        blocker,
                        key: const Key('checkout-blocked'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  if (progress != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          progress,
                          key: const Key('checkout-progress'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  BusyButton(
                    key: const Key('place-order'),
                    label: method == PaymentMethod.online
                        ? l10n.payAmount(grandTotal ?? '')
                        : l10n.placeOrder,
                    busy: checkout.busy,
                    onPressed: canPlace
                        ? () {
                            controller.selectMethod(method);
                            controller.placeOrder(
                              addressId: addressId,
                              expectedGrandTotal: bill.grandTotal,
                            );
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Another order is waiting for payment: offer to open it (retry or cancel
/// there) instead of placing a second one (DL-44).
Future<void> _showPendingOrder(BuildContext context, int orderId) async {
  final l10n = AppLocalizations.of(context);
  final open = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.pendingOrderTitle),
      content: Text(l10n.pendingOrderBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const Key('open-pending-order'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.pendingOrderAction),
        ),
      ],
    ),
  );
  if ((open ?? false) && context.mounted) {
    await context.push(Routes.paymentFailed(orderId));
  }
}
