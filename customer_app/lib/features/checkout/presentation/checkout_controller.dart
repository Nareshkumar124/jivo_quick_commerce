import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/pending_payment.dart';
import '../domain/checkout_result.dart';
import '../domain/idempotency_key.dart';

/// Where the place-order flow is.
enum CheckoutStep { idle, placing, paying, verifying }

@immutable
class CheckoutState {
  const CheckoutState({
    this.method = PaymentMethod.online,
    this.step = CheckoutStep.idle,
    this.result,
    this.error,
    this.pendingOrderId,
  });

  final PaymentMethod method;
  final CheckoutStep step;

  /// Where the flow ended; the screen navigates, then calls
  /// [CheckoutController.acknowledge].
  final CheckoutResult? result;

  /// Why placing the order failed (shown once, then acknowledged).
  final ApiError? error;

  /// Another order is still waiting for payment (409
  /// `INVALID_STATE_TRANSITION` with `details.pending_order_id`): offer to
  /// retry or cancel that one (DL-44).
  final int? pendingOrderId;

  /// The Place order button stays disabled (double-tap protection).
  bool get busy => step != CheckoutStep.idle;
}

/// Places the order and, for ONLINE, runs the payment (`03 §2.9`).
///
/// - `POST /orders/` carries an `Idempotency-Key`. When the outcome is
///   unknown (timeout, lost connection) the same key is sent on the next
///   tap, so the server returns the first order instead of a second one.
/// - COD: the server answers `PLACED` and the flow ends in success.
/// - ONLINE: Razorpay opens; success is reported only after the server's
///   verify call confirms the order (`08 §4`).
/// - `PRICE_CHANGED`, `STOCK_UNAVAILABLE`, `MIN_ORDER_NOT_MET`,
///   `COD_NOT_AVAILABLE` and the coupon errors reload the cart, so the
///   screens show the server's new bill and flags; the message says what
///   changed, from the error's `details` (`cartErrorText`).
/// - Another order awaiting payment: [CheckoutState.pendingOrderId].
/// - ONLINE and 503 `SERVICE_UNAVAILABLE` (the gateway is down, M6): the
///   server made the order and ended it `PAYMENT_FAILED`; the cart stays,
///   the error is published for the screen, and the next tap is a new
///   order (a definite answer retires the key).
class CheckoutController extends Notifier<CheckoutState> {
  String? _idempotencyKey;

  /// The request [_idempotencyKey] was first sent with. A changed request
  /// (address, method or total) is a new order and gets a new key.
  PlaceOrderRequest? _keyRequest;

  @override
  CheckoutState build() => const CheckoutState();

  void selectMethod(PaymentMethod method) {
    if (!state.busy) state = CheckoutState(method: method);
  }

  /// [expectedGrandTotal] is the server's total the customer is looking at.
  Future<void> placeOrder({
    required int addressId,
    required String expectedGrandTotal,
  }) async {
    if (state.busy) return;
    final method = state.method;
    state = CheckoutState(method: method, step: CheckoutStep.placing);
    final request = PlaceOrderRequest(
      addressId: addressId,
      paymentMethod: method,
      expectedGrandTotal: expectedGrandTotal,
    );
    if (!_sameRequest(_keyRequest, request)) _idempotencyKey = null;
    _keyRequest = request;
    final key = _idempotencyKey ??= ref.read(idempotencyKeyProvider)();

    final PlacedOrder order;
    try {
      order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(request, idempotencyKey: key);
    } catch (error) {
      final apiError = ApiError.from(error);
      if (!isOutcomeUnknown(apiError)) _idempotencyKey = null;
      if (_cartChanged(apiError)) {
        await ref.read(cartProvider.notifier).refresh(addressId: addressId);
      }
      final pending = apiError.code == ApiErrorCode.invalidStateTransition
          ? apiError.details['pending_order_id']
          : null;
      if (ref.mounted) {
        state = pending is num
            ? CheckoutState(method: method, pendingOrderId: pending.toInt())
            : CheckoutState(method: method, error: apiError);
      }
      return;
    }
    _idempotencyKey = null;

    if (order.status.isConfirmed) {
      await _finish(method, OrderConfirmed(order));
      return;
    }
    if (!ref.mounted) return;
    state = CheckoutState(method: method, step: CheckoutStep.paying);
    final result = await ref
        .read(paymentFlowProvider)
        .pay(
          order,
          onVerifying: () {
            if (ref.mounted) {
              state = CheckoutState(
                method: method,
                step: CheckoutStep.verifying,
              );
            }
          },
        );
    await _finish(method, result);
  }

  /// Publishes [result] first, so the screen leaves checkout before the
  /// (now empty) cart reloads and checkout would flash its empty state.
  Future<void> _finish(PaymentMethod method, CheckoutResult result) async {
    // Checkout opens this order's screen itself: Home must not open it a
    // second time when the pending-order check below finds it.
    ref.read(pendingPaymentProvider.notifier).takeAutoOpen(result.order.id);
    if (ref.mounted) state = CheckoutState(method: method, result: result);
    if (result is OrderConfirmed) {
      await onOrderConfirmed(ref, result.order);
    } else {
      // An order left unpaid: Home shows it until it is paid or cancelled.
      refreshPendingPayment(ref);
    }
  }

  /// The screen handled [CheckoutState.result] / [CheckoutState.error].
  void acknowledge() => state = CheckoutState(method: state.method);

  static bool _sameRequest(PlaceOrderRequest? a, PlaceOrderRequest b) =>
      a != null &&
      a.addressId == b.addressId &&
      a.paymentMethod == b.paymentMethod &&
      a.expectedGrandTotal == b.expectedGrandTotal;

  static bool _cartChanged(ApiError error) => switch (error.code) {
    ApiErrorCode.priceChanged ||
    ApiErrorCode.stockUnavailable ||
    ApiErrorCode.minOrderNotMet ||
    ApiErrorCode.codNotAvailable ||
    ApiErrorCode.couponExpired ||
    ApiErrorCode.couponNotEligible ||
    ApiErrorCode.couponUsageExceeded ||
    ApiErrorCode.couponInvalid => true,
    _ => false,
  };
}

/// After the server confirmed an order: it cleared the cart (`08` T2/T3),
/// so reload it, and log the purchase.
Future<void> onOrderConfirmed(Ref ref, PlacedOrder order) async {
  await ref
      .read(analyticsProvider)
      .logEvent(
        'purchase',
        parameters: {
          'order_id': '${order.id}',
          'payment_method': order.paymentMethod?.wireValue ?? 'UNKNOWN',
        },
      );
  await ref.read(cartProvider.notifier).refresh();
  refreshPendingPayment(ref);
}

/// Kept for the session (not auto-disposed) so an unknown-outcome
/// Idempotency-Key survives leaving the screen. Cleared on sign-out.
final checkoutProvider = NotifierProvider<CheckoutController, CheckoutState>(
  CheckoutController.new,
);
