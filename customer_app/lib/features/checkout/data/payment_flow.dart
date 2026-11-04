import 'package:flutter/foundation.dart';

import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../domain/checkout_result.dart';
import 'payment_launcher.dart';

/// Pays for a `PAYMENT_PENDING` order: opens the gateway, then verifies on
/// the server (`03 §2.9`, `08 §4`). Success is reported only when the
/// server's verify call returns a confirmed order; everything else goes to
/// the payment-failed screen, which re-reads the order's server status.
class PaymentFlow {
  const PaymentFlow({required this.orders, required this.launcher});

  final OrderRepository orders;
  final PaymentLauncher launcher;

  Future<CheckoutResult> pay(
    PlacedOrder order, {
    VoidCallback? onVerifying,
  }) async {
    final checkout = order.razorpay;
    if (checkout == null) return PaymentIncomplete(order);
    final outcome = await launcher.open(
      PaymentRequest(
        checkout: checkout,
        orderNumber: order.number,
        grandTotal: order.grandTotal,
      ),
    );
    switch (outcome) {
      case PaymentAuthorized():
        onVerifying?.call();
        try {
          final verified = await orders.verifyPayment(
            PaymentProof(
              orderId: order.id,
              razorpayOrderId: outcome.razorpayOrderId,
              razorpayPaymentId: outcome.razorpayPaymentId,
              razorpaySignature: outcome.razorpaySignature,
            ),
          );
          return verified.status.isConfirmed
              ? OrderConfirmed(verified)
              : PaymentIncomplete(verified);
        } catch (error) {
          return PaymentIncomplete(order, error: error);
        }
      case PaymentNotCompleted(:final reason):
        return PaymentIncomplete(order, reason: reason);
      case PaymentExternalWallet():
        // The result arrives by webhook: the next screen asks the server.
        return PaymentIncomplete(order);
    }
  }
}
