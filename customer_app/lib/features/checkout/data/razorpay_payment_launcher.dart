import 'dart:async';

import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_launcher.dart';

/// Opens Razorpay Standard Checkout (`razorpay_flutter` 1.4.7, pinned) with
/// the options `POST /orders/` returned (`RazorpayCheckout`): key, order id,
/// amount in paise, currency, name, description, prefill and the remaining
/// window as `timeout`, all passed through unchanged.
///
/// One checkout at a time: a second [open] while one is showing returns
/// [PaymentFailureReason.unknown] without opening anything (the screens
/// also disable the button while a payment is in flight).
///
/// **Stale results.** When the app is killed while checkout is open, the
/// plugin keeps the result that arrives later and replays it on the next
/// `Razorpay.on()` (its `resync`), which would end the *next* checkout with
/// an old answer. [open] drains that reply first (the server settles the old
/// order by webhook, `08 §4`), and ignores success and error events that
/// name a different Razorpay order. External-wallet events carry no order
/// id; they only send the customer to the server's status, so they are
/// harmless.
///
/// **Safety timeout.** If no event ever arrives (e.g. a dropped reply),
/// [open] gives up after the payment window plus a margin and reports
/// [PaymentFailureReason.unknown]; the payment screen then asks the server.
class RazorpayPaymentLauncher implements PaymentLauncher {
  RazorpayPaymentLauncher({
    Razorpay Function()? create,
    Future<void> Function()? dropStaleResult,
    Duration Function(PaymentRequest request)? safetyTimeout,
  }) : _create = create ?? Razorpay.new,
       _dropStaleResult = dropStaleResult ?? _resyncAndDiscard,
       _safetyTimeout = safetyTimeout ?? defaultSafetyTimeout;

  final Razorpay Function() _create;
  final Future<void> Function() _dropStaleResult;
  final Duration Function(PaymentRequest request) _safetyTimeout;
  bool _open = false;

  /// The plugin's own channel and `resync` call (razorpay_flutter 1.4.7):
  /// it returns, and forgets, a result that arrived with no listener.
  /// Re-check on any plugin upgrade.
  static const _pluginChannel = MethodChannel('razorpay_flutter');

  static Future<void> _resyncAndDiscard() async {
    try {
      await _pluginChannel.invokeMethod<Object?>('resync');
    } on Object {
      // Nothing to drop (or no plugin, e.g. in tests).
    }
  }

  /// The payment window from the server (`timeout_seconds`, else 15 min)
  /// plus 2 minutes, at most 30 minutes.
  static Duration defaultSafetyTimeout(PaymentRequest request) {
    final window = request.checkout.timeoutSeconds ?? 15 * 60;
    final seconds = window + 120;
    return Duration(seconds: seconds > 30 * 60 ? 30 * 60 : seconds);
  }

  /// The checkout options for [request]: the server's values, unchanged.
  static Map<String, Object?> optionsFor(PaymentRequest request) {
    final checkout = request.checkout;
    return {
      'key': checkout.keyId,
      'order_id': checkout.orderId,
      'amount': checkout.amountPaise,
      'currency': checkout.currency,
      'name': checkout.name,
      'description': checkout.description,
      'timeout': ?checkout.timeoutSeconds,
      'prefill': {
        'name': ?checkout.prefillName,
        'email': ?checkout.prefillEmail,
        'contact': ?checkout.prefillContact,
      },
    };
  }

  /// Maps the SDK's error code (`Razorpay.PAYMENT_CANCELLED`, …).
  static PaymentFailureReason reasonFor(int? code) => switch (code) {
    Razorpay.PAYMENT_CANCELLED => PaymentFailureReason.cancelled,
    Razorpay.NETWORK_ERROR ||
    Razorpay.TLS_ERROR => PaymentFailureReason.network,
    Razorpay.INVALID_OPTIONS => PaymentFailureReason.invalidOptions,
    _ => PaymentFailureReason.unknown,
  };

  /// The outcome of a success callback. A response without the ids or the
  /// signature can't be verified, so the app asks the server instead.
  static PaymentOutcome successOutcome(PaymentSuccessResponse response) {
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (orderId == null || paymentId == null || signature == null) {
      return const PaymentNotCompleted(PaymentFailureReason.unknown);
    }
    return PaymentAuthorized(
      razorpayOrderId: orderId,
      razorpayPaymentId: paymentId,
      razorpaySignature: signature,
    );
  }

  /// The Razorpay order an error event is about, when Razorpay said
  /// (`responseBody.metadata.order_id`).
  static String? errorOrderId(PaymentFailureResponse response) {
    final metadata = response.error?['metadata'];
    final orderId = metadata is Map ? metadata['order_id'] : null;
    return orderId is String && orderId.isNotEmpty ? orderId : null;
  }

  @override
  Future<PaymentOutcome> open(PaymentRequest request) async {
    if (_open) return const PaymentNotCompleted(PaymentFailureReason.unknown);
    _open = true;
    final expected = request.checkout.orderId;
    final result = Completer<PaymentOutcome>();
    void finish(PaymentOutcome outcome) {
      if (!result.isCompleted) result.complete(outcome);
    }

    Razorpay? razorpay;
    try {
      await _dropStaleResult();
      razorpay = _create()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (Object? response) {
          if (response is! PaymentSuccessResponse) {
            finish(const PaymentNotCompleted(PaymentFailureReason.unknown));
            return;
          }
          // A late answer for another Razorpay order is not this payment.
          final orderId = response.orderId;
          if (orderId != null && orderId != expected) return;
          finish(successOutcome(response));
        })
        ..on(Razorpay.EVENT_PAYMENT_ERROR, (Object? response) {
          if (response is PaymentFailureResponse) {
            final orderId = errorOrderId(response);
            if (orderId != null && orderId != expected) return;
          }
          finish(
            PaymentNotCompleted(
              reasonFor(
                response is PaymentFailureResponse ? response.code : null,
              ),
            ),
          );
        })
        ..on(Razorpay.EVENT_EXTERNAL_WALLET, (Object? response) {
          finish(
            PaymentExternalWallet(
              response is ExternalWalletResponse ? response.walletName : null,
            ),
          );
        })
        ..open(optionsFor(request));
      return await result.future.timeout(
        _safetyTimeout(request),
        onTimeout: () =>
            const PaymentNotCompleted(PaymentFailureReason.unknown),
      );
    } on Object {
      return const PaymentNotCompleted(PaymentFailureReason.unknown);
    } finally {
      razorpay?.clear();
      _open = false;
    }
  }
}
