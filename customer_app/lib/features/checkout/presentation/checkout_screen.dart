import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/redirect.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/formatting/formatters.dart';
import '../../../shared/widgets/state_views.dart';
import '../../addresses/presentation/address_controllers.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../cart/presentation/cart_texts.dart';
import '../../cart/presentation/widgets/bill_details.dart';
import '../../cart/presentation/widgets/free_line_tile.dart';
import '../../cart/presentation/widgets/checkout_blocker.dart';
import '../../cart/presentation/widgets/delivery_address_card.dart';
import '../../location/presentation/delivery_controller.dart';
import '../../orders/domain/order.dart';
import '../../referral/presentation/referral_prompt_card.dart';
import '../domain/checkout_result.dart';
import 'checkout_controller.dart';
import 'payment_failed_screen.dart';

/// Payment method and Place order (`03 §2.9`, screen #22).
///
/// Cash on Delivery is offered only when the server says the cart is
/// eligible. The button is disabled while the order is placed and paid
/// (double-tap protection), and Back is blocked until the flow ends.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    // The checkout state lives for the session: a notice from an earlier
    // visit is stale on a fresh one (CA-19).
    Future.microtask(() {
      if (mounted) ref.read(checkoutProvider.notifier).clearPriceChange();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        final online =
            ref.read(checkoutProvider).method == PaymentMethod.online;
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
        // An account without a phone (email sign-up): the order needs a
        // contact number, which lives on the delivery address.
        if (error.code == ApiErrorCode.phoneRequired) {
          showMessage(context, describeErrorWithDetails(context, error));
          final id = ref.read(deliveryProvider).location?.addressId;
          if (id != null) context.push(Routes.editAddress(id));
          return;
        }
        // A changed total stays on screen as a notice above the payment
        // methods instead of a snackbar that is easy to miss (CA-19).
        if (priceChangeOf(error) != null) return;
        // What changed, from the error's details; the cart was reloaded.
        showMessage(context, cartErrorText(context, error, cart: snapshot));
        // Flagged lines, and too few units, are fixed on the cart screen.
        final flagged =
            error.code == ApiErrorCode.stockUnavailable ||
            error.code == ApiErrorCode.minQtyRequired ||
            error.code == ApiErrorCode.minUnitsNotMet;
        if (flagged && context.canPop()) context.pop();
      })
      ..listen(checkoutProvider.select((s) => s.pendingOrderId), (_, id) {
        if (id == null) return;
        controller.acknowledge();
        _showPendingOrder(context, id);
      });

    final bill = snapshot.bill;
    if (snapshot.isEmpty || bill == null) {
      return Theme(
        data: lightPageTheme(Theme.of(context)),
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.checkoutTitle)),
          body: EmptyView(
            message: l10n.cartEmpty,
            icon: Icons.shopping_bag_outlined,
            action: FilledButton(
              onPressed: () => context.go(Routes.home),
              child: Text(l10n.startShopping),
            ),
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
    // An email sign-up without a phone must give a contact number on the
    // delivery address before ordering (the rider and the store call it).
    // Unknown (addresses still loading) does not block: the server answers
    // PHONE_REQUIRED, handled above.
    final noPhone = ref.watch(signedInUserHasPhoneProvider) == false;
    final address = noPhone && addressId != null
        ? ref
              .watch(addressListProvider)
              .value
              ?.where((a) => a.id == addressId)
              .firstOrNull
        : null;
    final needsContactPhone =
        address != null && (address.input.receiverPhone ?? '').isEmpty;
    // The server decides (`Cart.checkout`); the order also needs a saved
    // address id and an offered method.
    // A total that can't be shown can't be paid (RD-02).
    final grandTotal = formatRupeesOrNull(bill.grandTotal);
    final canPlace =
        !checkout.busy &&
        grandTotal != null &&
        addressId != null &&
        snapshot.checkout.canPlaceOrder &&
        offered.contains(method) &&
        !needsContactPhone;
    final blocker = snapshot.checkout.canPlaceOrder
        ? null
        : checkoutBlockerText(l10n, snapshot);
    final progress = switch (checkout.step) {
      CheckoutStep.idle => null,
      CheckoutStep.placing => l10n.checkoutPlacing,
      CheckoutStep.paying => l10n.checkoutPaying,
      CheckoutStep.verifying => l10n.checkoutVerifying,
    };

    return Theme(
      data: lightPageTheme(Theme.of(context)),
      child: PopScope(
        canPop: !checkout.busy,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.checkoutTitle)),
          body: ListView(
            padding: const EdgeInsets.all(JivoSpacing.gutter),
            children: [
              const DeliveryAddressCard(),
              const SizedBox(height: JivoSpacing.lg),
              // Only while the bill on screen is the changed one: after the
              // cart changes again the notice is stale (CA-19).
              if (checkout.priceChange case final change?
                  when isSameAmount(change.after, bill.grandTotal)) ...[
                PriceChangedNotice(change: change),
                const SizedBox(height: JivoSpacing.lg),
              ],
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
                      if (!snapshot.offers(PaymentMethod.cod) &&
                          snapshot.paymentOptions.any(
                            (o) => o.method == PaymentMethod.cod,
                          ))
                        CodUnavailableTile(
                          message: snapshot.paymentOptions
                              .firstWhere((o) => o.method == PaymentMethod.cod)
                              .message,
                        ),
                    ],
                  ),
                ),
              ),
              // The free cartons at ₹0 (ADR 0002), above the bill.
              if (snapshot.freeLines.isNotEmpty) ...[
                const SizedBox(height: JivoSpacing.lg),
                Card(
                  key: const Key('checkout-free-lines'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(JivoSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.checkoutFreeCartonsTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: JivoSpacing.sm),
                        for (final line in snapshot.freeLines)
                          FreeLineRow(
                            line: line,
                            every: snapshot.freeOffer?.every,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: JivoSpacing.lg),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(JivoSpacing.lg),
                  child: BillDetails(bill: bill, coupon: snapshot.coupon),
                ),
              ),
              if (!checkout.busy) const ReferralPromptCard(),
            ],
          ),
          // A white bar under a hairline (home redesign).
          bottomNavigationBar: Material(
            color: theme.colorScheme.surfaceContainerLowest,
            shape: Border(
              top: BorderSide(color: context.customerColors.hairline),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(JivoSpacing.gutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (blocker != null && !checkout.busy)
                      CheckoutBlockerText(blocker)
                    else if (needsContactPhone && !checkout.busy) ...[
                      CheckoutBlockerText(l10n.checkoutContactPhoneNeeded),
                      Padding(
                        padding: const EdgeInsets.only(bottom: JivoSpacing.sm),
                        child: OutlinedButton.icon(
                          key: const Key('checkout-add-contact-phone'),
                          icon: const Icon(Icons.phone_android),
                          label: Text(l10n.addContactPhone),
                          onPressed: () =>
                              context.push(Routes.editAddress(addressId!)),
                        ),
                      ),
                    ],
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

/// The total changed at Place order (`PRICE_CHANGED`, CA-19): a notice that
/// stays until an order is placed or the method changes. Both amounts are
/// the server's, from the error's details.
class PriceChangedNotice extends StatelessWidget {
  const PriceChangedNotice({required this.change, super.key});

  final PriceChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.customerColors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('price-changed-notice'),
        padding: const EdgeInsets.all(JivoSpacing.md),
        decoration: BoxDecoration(
          color: colors.warningTint,
          borderRadius: BorderRadius.circular(JivoRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.info_outline,
                color: context.jivoColors.warning,
              ),
            ),
            const SizedBox(width: JivoSpacing.sm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l10n.priceChangedNoticeTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: l10n.priceChangedNoticeBody(
                        displayRupees(change.before),
                        displayRupees(change.after),
                      ),
                    ),
                  ],
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cash on Delivery the server marked unavailable: greyed out, not
/// selectable, with the server's reason shown as is (CA-21).
class CodUnavailableTile extends StatelessWidget {
  const CodUnavailableTile({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = (message == null || message!.trim().isEmpty)
        ? l10n.codUnavailableFallback
        : message!;
    return RadioListTile<PaymentMethod>(
      key: const Key('pay-cod-unavailable'),
      value: PaymentMethod.cod,
      enabled: false,
      secondary: const Icon(Icons.payments_outlined),
      title: Text(l10n.payCod),
      subtitle: Text(text),
      isThreeLine: false,
    );
  }
}
