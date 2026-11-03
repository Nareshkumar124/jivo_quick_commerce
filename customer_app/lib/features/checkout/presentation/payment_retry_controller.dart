import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../orders/domain/order.dart';
import '../data/payment_launcher.dart';
import '../domain/checkout_result.dart';
import '../domain/idempotency_key.dart';
import 'checkout_controller.dart';

/// What the payment-failed screen is doing.
enum RetryAction { retrying, cancelling, changingMethod }

/// Where to go after the unpaid order was cancelled (T5).
enum AfterCancel { cart, checkout }

@immutable
class PaymentRetryState {
  const PaymentRetryState({
    this.order,
    this.loading = false,
    this.loadError,
    this.action,
    this.reason,
    this.error,
    this.confirmed,
    this.afterCancel,
    this.retried = false,
  });

  /// The order as the server last reported it.
  final PlacedOrder? order;
  final bool loading;
  final Object? loadError;
  final RetryAction? action;

  /// What the gateway reported on the last attempt.
  final PaymentFailureReason? reason;

  /// The last action's failure (shown once).
  final Object? error;

  /// The server confirmed the order: go to the success screen.
  final PlacedOrder? confirmed;

  /// The order was cancelled: go here.
  final AfterCancel? afterCancel;

  /// A retry was attempted here; until then the screen shows what checkout
  /// reported.
  final bool retried;

  bool get busy => action != null;

  PaymentRetryState copyWith({
    PlacedOrder? order,
    bool? loading,
    Object? loadError,
    RetryAction? action,
    bool clearAction = false,
    PaymentFailureReason? reason,
    bool clearReason = false,
    Object? error,
    bool clearError = false,
    PlacedOrder? confirmed,
    AfterCancel? afterCancel,
    bool? retried,
  }) => PaymentRetryState(
    order: order ?? this.order,
    loading: loading ?? this.loading,
    loadError: loadError,
    action: clearAction ? null : (action ?? this.action),
    reason: clearReason ? null : (reason ?? this.reason),
    error: clearError ? null : (error ?? this.error),
    confirmed: confirmed ?? this.confirmed,
    afterCancel: afterCancel ?? this.afterCancel,
    retried: retried ?? this.retried,
  );
}

/// The payment-failed screen for one order (`03 §2.9`, screen #23): it
/// first asks the server for the order's status (the webhook may have
/// confirmed a payment the app never heard about), then offers Retry
/// (within the payment window), Change method and Cancel order (T5).
class PaymentRetryController extends Notifier<PaymentRetryState> {
  PaymentRetryController(this.orderId);

  final int orderId;
  String? _idempotencyKey;

  @override
  PaymentRetryState build() {
    Future.microtask(reload);
    return const PaymentRetryState(loading: true);
  }

  Future<void> reload() async {
    if (!ref.mounted) return;
    state = state.copyWith(loading: true);
    try {
      final order = await ref.read(orderRepositoryProvider).getOrder(orderId);
      if (!ref.mounted) return;
      state = state.copyWith(
        order: order,
        loading: false,
        confirmed: order.status.isConfirmed ? order : null,
      );
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, loadError: error);
      }
    }
  }

  /// `POST /orders/{id}/retry-payment/`, then the gateway and verify.
  Future<void> retry() async {
    if (state.busy) return;
    state = state.copyWith(
      action: RetryAction.retrying,
      clearError: true,
      clearReason: true,
      retried: true,
    );
    final key = _idempotencyKey ??= ref.read(idempotencyKeyProvider)();
    final PlacedOrder order;
    try {
      order = await ref
          .read(orderRepositoryProvider)
          .retryPayment(orderId, idempotencyKey: key);
      _idempotencyKey = null;
    } catch (error) {
      final apiError = ApiError.from(error);
      if (!isOutcomeUnknown(apiError)) _idempotencyKey = null;
      if (!ref.mounted) return;
      state = state.copyWith(clearAction: true, error: apiError);
      // The order may have moved on (paid by webhook, or expired).
      if (apiError.code == ApiErrorCode.invalidStateTransition) await reload();
      return;
    }
    final result = await ref.read(paymentFlowProvider).pay(order);
    if (result is OrderConfirmed) await onOrderConfirmed(ref, result.order);
    if (!ref.mounted) return;
    state = switch (result) {
      OrderConfirmed(:final order) => state.copyWith(
        order: order,
        clearAction: true,
        confirmed: order,
      ),
      PaymentIncomplete(:final order, :final reason, :final error) =>
        state.copyWith(
          order: order,
          clearAction: true,
          reason: reason,
          error: error,
        ),
    };
  }

  /// T5: abandon the unpaid order. With [changeMethod] the customer goes
  /// back to checkout to pick another method; otherwise to the cart.
  Future<void> cancel({bool changeMethod = false}) async {
    if (state.busy) return;
    state = state.copyWith(
      action: changeMethod
          ? RetryAction.changingMethod
          : RetryAction.cancelling,
      clearError: true,
    );
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .cancelOrder(orderId);
      await ref.read(cartProvider.notifier).refresh();
      if (!ref.mounted) return;
      state = state.copyWith(
        order: order,
        clearAction: true,
        afterCancel: changeMethod ? AfterCancel.checkout : AfterCancel.cart,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(clearAction: true, error: ApiError.from(error));
      await reload();
    }
  }
}

final paymentRetryProvider = NotifierProvider.autoDispose
    .family<PaymentRetryController, PaymentRetryState, int>(
      PaymentRetryController.new,
    );
