import '../../orders/domain/order.dart';
import '../data/payment_launcher.dart';

/// Where a checkout or a payment retry ended.
sealed class CheckoutResult {
  const CheckoutResult(this.order);

  final PlacedOrder order;
}

/// The server confirmed the order (COD placed, or the payment verified):
/// show the success screen.
final class OrderConfirmed extends CheckoutResult {
  const OrderConfirmed(super.order);
}

/// The order exists but is not paid: show the payment-failed screen, which
/// asks the server for the latest status first (the webhook may have
/// confirmed the payment meanwhile).
final class PaymentIncomplete extends CheckoutResult {
  const PaymentIncomplete(super.order, {this.reason, this.error});

  /// What the gateway reported, when it reported a failure.
  final PaymentFailureReason? reason;

  /// The verify call's failure, e.g. `PAYMENT_VERIFICATION_FAILED`.
  final Object? error;
}
