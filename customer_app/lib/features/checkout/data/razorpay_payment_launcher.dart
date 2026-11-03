import 'dart:async';

import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_launcher.dart';

/// Opens Razorpay Standard Checkout (`razorpay_flutter`) with what
/// `POST /orders/` returned: the public `key_id`, the Razorpay `order_id`,
/// the amount and the prefill (`06 §2.6`). The amount comes from the server
/// and is passed through unchanged.
///
/// One checkout at a time: a second [open] while one is showing returns
/// [PaymentFailureReason.unknown] without opening anything (the screens
/// also disable the button while a payment is in flight).
///
/// **Stale results.** When the app is killed while Razorpay checkout is
/// open, the plugin keeps the result that arrives later and replays it on
/// the next `Razorpay.on()` (its `resync`), which would finish the *next*
/// checkout with an old answer. [open] therefore drains that reply first
/// (the server settles the old order by webhook, `08 §4`), and ignores a
/// success for a different Razorpay order.
class RazorpayPaymentLauncher implements PaymentLauncher {
  RazorpayPaymentLauncher({
    Razorpay Function()? create,
    Future<void> Function()? dropStaleResult,
  }) : _create = create ?? Razorpay.new,
       _dropStaleResult = dropStaleResult ?? _resyncAndDiscard;

  final Razorpay Function() _create;
  final Future<void> Function() _dropStaleResult;
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

  /// The checkout options for [request] (Razorpay's documented keys).
  static Map<String, Object?> optionsFor(PaymentRequest request) {
    final checkout = request.checkout;
    return {
      'key': checkout.keyId,
      'order_id': checkout.orderId,
      'amount': checkout.amountPaise,
      'currency': checkout.currency,
      'name': 'Jivo',
      'description': 'Order ${request.orderNumber}',
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
  /// signature can't be verified, so the app asks the server instead
  /// (treated like an unconfirmed payment).
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

  @override
  Future<PaymentOutcome> open(PaymentRequest request) async {
    if (_open) return const PaymentNotCompleted(PaymentFailureReason.unknown);
    _open = true;
    final result = Completer<PaymentOutcome>();
    void finish(PaymentOutcome outcome) {
      if (!result.isCompleted) result.complete(outcome);
    }

    Razorpay? razorpay;
    try {
      await _dropStaleResult();
      razorpay = _create()
        ..on(Razorpay.EVENT_PAYMENT_SUCCESS, (Object? response) {
          // A late answer for another Razorpay order is not this payment.
          if (response is PaymentSuccessResponse &&
              response.orderId != null &&
              response.orderId != request.checkout.orderId) {
            return;
          }
          finish(
            response is PaymentSuccessResponse
                ? successOutcome(response)
                : const PaymentNotCompleted(PaymentFailureReason.unknown),
          );
        })
        ..on(Razorpay.EVENT_PAYMENT_ERROR, (Object? response) {
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
      return await result.future;
    } on Object {
      return const PaymentNotCompleted(PaymentFailureReason.unknown);
    } finally {
      razorpay?.clear();
      _open = false;
    }
  }
}
