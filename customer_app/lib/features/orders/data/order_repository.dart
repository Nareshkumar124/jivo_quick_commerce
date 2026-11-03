import 'package:jivo_core/jivo_core.dart';

import '../domain/order.dart';

/// Placing and paying for orders (`03 §2.9`, `06 §2.6`). Implementations
/// throw `ApiError` (`PRICE_CHANGED`, `STOCK_UNAVAILABLE`,
/// `MIN_ORDER_NOT_MET`, `COD_NOT_AVAILABLE`, `STORE_CLOSED`,
/// `PAYMENT_VERIFICATION_FAILED`, `INVALID_STATE_TRANSITION`, …).
abstract interface class OrderRepository {
  /// `POST /orders/` with `Idempotency-Key` and `X-Store-Id`. COD orders
  /// come back `PLACED`; ONLINE orders `PAYMENT_PENDING` with
  /// [PlacedOrder.razorpay]. The same [idempotencyKey] returns the same
  /// order. While another order awaits payment the server answers 409
  /// `INVALID_STATE_TRANSITION` with `details.pending_order_id`.
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

  /// `POST /orders/{id}/cancel/ {reason}`: in Phase 3 only T5, abandoning a
  /// `PAYMENT_PENDING` order. The cart stays.
  Future<PlacedOrder> cancelOrder(int orderId, {required CancelReason reason});

  /// The order's status as the server has it now (e.g. after a webhook
  /// confirmed a payment the app never heard back about).
  Future<PlacedOrder> getOrder(int orderId);

  /// `GET /orders/?status=active`: every non-terminal order,
  /// `PAYMENT_PENDING` included (recovering a payment after the app was
  /// closed, `03 §2.9`).
  Future<List<PlacedOrder>> activeOrders();
}

/// Staging and prod until the cart is enabled there (S3-B). The cart is
/// unavailable, so checkout is unreachable and this is never called.
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
  Future<PlacedOrder> cancelOrder(
    int orderId, {
    required CancelReason reason,
  }) => _unavailable();

  @override
  Future<PlacedOrder> getOrder(int orderId) => _unavailable();

  @override
  Future<List<PlacedOrder>> activeOrders() async => const [];
}
