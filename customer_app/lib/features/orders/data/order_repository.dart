import 'package:jivo_core/jivo_core.dart';

import '../domain/order.dart';

/// Placing and paying for orders (`03 §2.9`, `06 §2.6`). Implementations
/// throw `ApiError` (`PRICE_CHANGED`, `STOCK_UNAVAILABLE`,
/// `MIN_ORDER_NOT_MET`, `COD_NOT_AVAILABLE`, `STORE_CLOSED`,
/// `PAYMENT_VERIFICATION_FAILED`, `INVALID_STATE_TRANSITION`, …).
abstract interface class OrderRepository {
  /// `POST /orders/` with the `Idempotency-Key` header. COD orders come back
  /// `PLACED`; ONLINE orders come back `PAYMENT_PENDING` with
  /// [PlacedOrder.razorpay]. Sending the same [idempotencyKey] again returns
  /// the same order instead of a second one.
  Future<PlacedOrder> placeOrder(
    PlaceOrderRequest request, {
    required String idempotencyKey,
  });

  /// `POST /payments/razorpay/verify/`. Returns the order, `PLACED` when the
  /// signature checks out; throws `PAYMENT_VERIFICATION_FAILED` otherwise.
  Future<PlacedOrder> verifyPayment(PaymentProof proof);

  /// `POST /orders/{id}/retry-payment/`: a new Razorpay order for a
  /// `PAYMENT_PENDING` order inside the payment window.
  Future<PlacedOrder> retryPayment(
    int orderId, {
    required String idempotencyKey,
  });

  /// `POST /orders/{id}/cancel/`: here only T5, abandoning a
  /// `PAYMENT_PENDING` order from the payment-failed screen (`08 §2`).
  Future<PlacedOrder> cancelOrder(int orderId);

  /// `GET /orders/{id}/`: the server's status, e.g. after the webhook
  /// confirmed a payment the app never heard back about.
  Future<PlacedOrder> getOrder(int orderId);
}

/// Staging and prod until the Phase 3 order API is wired (S3-A). The cart is
/// unavailable there, so checkout is unreachable and this is never called.
class UnavailableOrderRepository implements OrderRepository {
  const UnavailableOrderRepository();

  static Never _unavailable() =>
      throw const ApiError(code: ApiErrorCode.serviceUnavailable);

  @override
  Future<PlacedOrder> placeOrder(
    PlaceOrderRequest request, {
    required String idempotencyKey,
  }) => _unavailable();

  @override
  Future<PlacedOrder> verifyPayment(PaymentProof proof) => _unavailable();

  @override
  Future<PlacedOrder> retryPayment(
    int orderId, {
    required String idempotencyKey,
  }) => _unavailable();

  @override
  Future<PlacedOrder> cancelOrder(int orderId) => _unavailable();

  @override
  Future<PlacedOrder> getOrder(int orderId) => _unavailable();
}
