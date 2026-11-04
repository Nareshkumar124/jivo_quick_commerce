import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/pending_payment.dart';
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
    this.serverChecked = false,
    this.loading = false,
    this.loadError,
    this.action,
    this.reason,
    this.error,
    this.confirmed,
    this.afterCancel,
    this.retried = false,
  });

  /// The order as the server last reported it on this screen.
  final PlacedOrder? order;

  /// A server status read succeeded during this visit, and no payment
  /// attempt has ended unconfirmed since. Retry, Cancel and Change method
  /// need it: without a fresh read the order may already be paid.
  final bool serverChecked;
  final bool loading;

  /// The last status read failed.
  final Object? loadError;
  final RetryAction? action;

  /// What the gateway reported on the last attempt here.
  final PaymentFailureReason? reason;

  /// The last action's failure (shown inline).
  final Object? error;

  /// The server confirmed the order: go to the success screen.
  final PlacedOrder? confirmed;

  /// The order was cancelled: go here.
  final AfterCancel? afterCancel;

  /// A retry was attempted here; until then the screen shows what checkout
  /// reported.
  final bool retried;

  bool get busy => action != null;

  /// Retry only on the server's word: a fresh read that allows it
  /// (`can_retry_payment`, which already accounts for the window).
  bool get canRetry =>
      serverChecked && !busy && !loading && (order?.canRetryPayment ?? false);

  /// Cancel and Change method only on the server's word (`can_cancel`).
  bool get canCancel =>
      serverChecked && !busy && !loading && (order?.canCancel ?? false);

  PaymentRetryState copyWith({
    PlacedOrder? order,
    bool? serverChecked,
    bool? loading,
    Object? loadError,
    bool clearLoadError = false,
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
    serverChecked: serverChecked ?? this.serverChecked,
    loading: loading ?? this.loading,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    action: clearAction ? null : (action ?? this.action),
    reason: clearReason ? null : (reason ?? this.reason),
    error: clearError ? null : (error ?? this.error),
    confirmed: confirmed ?? this.confirmed,
    afterCancel: afterCancel ?? this.afterCancel,
    retried: retried ?? this.retried,
  );
}

/// The payment-failed screen for one order (`03 §2.9`, screen #23).
///
/// It first reads the order's status from the server (the webhook may have
/// confirmed a payment the app never heard about). The server's status and
/// flags are authoritative: Retry needs `can_retry_payment`, Cancel and
/// Change method need `can_cancel`, and both need a read that succeeded on
/// this visit. After an attempt that ends unconfirmed the status is read
/// again before anything else is allowed. The device clock only drives the
/// "Pay by" hint.
class PaymentRetryController extends Notifier<PaymentRetryState> {
  PaymentRetryController(this.orderId);

  final int orderId;
  String? _idempotencyKey;

  /// The latest status read: only its answer counts, so a slow, older read
  /// can't overwrite a newer one.
  int _latestLoad = 0;

  @override
  PaymentRetryState build() {
    Future.microtask(reload);
    return const PaymentRetryState(loading: true);
  }

  /// Reads the order's status from the server.
  Future<void> reload() async {
    if (!ref.mounted) return;
    final ticket = ++_latestLoad;
    state = state.copyWith(loading: true, clearLoadError: true);
    try {
      final order = await ref.read(orderRepositoryProvider).getOrder(orderId);
      if (!ref.mounted || ticket != _latestLoad) return;
      state = state.copyWith(
        order: order,
        serverChecked: true,
        loading: false,
        confirmed: order.status.isConfirmed ? order : null,
      );
    } catch (error) {
      if (ref.mounted && ticket == _latestLoad) {
        state = state.copyWith(
          serverChecked: false,
          loading: false,
          loadError: error,
        );
      }
    }
  }

  /// `POST /orders/{id}/retry-payment/`, then the gateway and verify.
  Future<void> retry() async {
    if (!state.canRetry) return;
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
      state = state.copyWith(
        clearAction: true,
        serverChecked: false,
        error: apiError,
      );
      // The order may have moved on (paid by webhook, or expired).
      await reload();
      return;
    }
    final result = await ref.read(paymentFlowProvider).pay(order);
    if (!ref.mounted) return;
    switch (result) {
      case OrderConfirmed(:final order):
        state = state.copyWith(
          order: order,
          clearAction: true,
          confirmed: order,
        );
        await onOrderConfirmed(ref, order);
      case PaymentIncomplete(:final order, :final reason, :final error):
        state = state.copyWith(
          order: order,
          serverChecked: false,
          clearAction: true,
          reason: reason,
          error: error,
        );
        // Ask the server before allowing anything else.
        await reload();
    }
  }

  /// T5: abandon the unpaid order. With [changeMethod] the customer goes
  /// back to checkout to pick another method (reason
  /// `CHANGE_PAYMENT_METHOD`); otherwise to the cart (`PAYMENT_PROBLEM`).
  Future<void> cancel({bool changeMethod = false}) async {
    if (!state.canCancel) return;
    state = state.copyWith(
      action: changeMethod
          ? RetryAction.changingMethod
          : RetryAction.cancelling,
      clearError: true,
    );
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .cancelOrder(
            orderId,
            reason: changeMethod
                ? CancelReason.changePaymentMethod
                : CancelReason.paymentProblem,
          );
      await ref.read(cartProvider.notifier).refresh();
      if (!ref.mounted) return;
      refreshPendingPayment(ref);
      state = state.copyWith(
        order: order,
        clearAction: true,
        afterCancel: changeMethod ? AfterCancel.checkout : AfterCancel.cart,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        clearAction: true,
        serverChecked: false,
        error: ApiError.from(error),
      );
      await reload();
    }
  }
}

final paymentRetryProvider = NotifierProvider.autoDispose
    .family<PaymentRetryController, PaymentRetryState, int>(
      PaymentRetryController.new,
    );
