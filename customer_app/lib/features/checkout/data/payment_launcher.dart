import 'package:flutter/foundation.dart';

import '../../orders/domain/order.dart';

/// Opens the payment gateway's checkout for an ONLINE order (`03 §2.9`).
///
/// The outcome is only what the gateway's SDK told the app. It is never
/// proof of payment: success is shown only after the server verifies it
/// (`08 §4` rule 1).
abstract interface class PaymentLauncher {
  Future<PaymentOutcome> open(PaymentRequest request);
}

/// What to pay for.
@immutable
class PaymentRequest {
  const PaymentRequest({
    required this.checkout,
    required this.orderNumber,
    required this.grandTotal,
  });

  final RazorpayCheckout checkout;

  /// Our order number, for the checkout description.
  final String orderNumber;

  /// The server's grand total, for display only.
  final String grandTotal;
}

/// What the gateway's SDK reported.
sealed class PaymentOutcome {
  const PaymentOutcome();
}

/// The SDK reports success: send these to the server's verify endpoint.
final class PaymentAuthorized extends PaymentOutcome {
  const PaymentAuthorized({
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
  });

  final String razorpayOrderId;
  final String razorpayPaymentId;
  final String razorpaySignature;
}

/// Why checkout ended without a payment.
enum PaymentFailureReason { cancelled, network, invalidOptions, unknown }

/// The SDK reports a failure or the customer closed checkout.
final class PaymentNotCompleted extends PaymentOutcome {
  const PaymentNotCompleted(this.reason);

  final PaymentFailureReason reason;
}

/// The customer chose an external wallet: the result arrives through the
/// server (webhook), so the app checks the order's status.
final class PaymentExternalWallet extends PaymentOutcome {
  const PaymentExternalWallet(this.walletName);

  final String? walletName;
}
