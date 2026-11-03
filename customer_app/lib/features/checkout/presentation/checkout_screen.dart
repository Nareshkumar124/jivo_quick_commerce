import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/redirect.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../cart/presentation/cart_controller.dart';
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
    final storeClosed = ref.watch(
      deliveryProvider.select((s) => s.serviceability?.storeClosed ?? false),
    );

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
        controller.acknowledge();
        showMessage(context, describeErrorWithDetails(context, error));
        // Flagged lines are fixed on the cart screen.
        if (error.code == ApiErrorCode.stockUnavailable && context.canPop()) {
          context.pop();
        }
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

    final method =
        checkout.method == PaymentMethod.cod && !snapshot.codAvailable
        ? PaymentMethod.online
        : checkout.method;
    final addressId = location?.addressId;
    final canPlace =
        !checkout.busy &&
        addressId != null &&
        !storeClosed &&
        !snapshot.hasProblems &&
        (snapshot.minimumOrder?.met ?? true);
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
                    RadioListTile<PaymentMethod>(
                      key: const Key('pay-online'),
                      value: PaymentMethod.online,
                      enabled: !checkout.busy,
                      secondary: const Icon(Icons.account_balance_outlined),
                      title: Text(l10n.payOnline),
                      subtitle: Text(l10n.payOnlineSubtitle),
                    ),
                    if (snapshot.codAvailable)
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
                        ? l10n.payAmount(formatRupees(bill.grandTotal))
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
