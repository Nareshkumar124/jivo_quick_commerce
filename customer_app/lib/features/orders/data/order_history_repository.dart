import 'package:jivo_core/jivo_core.dart';

import '../domain/order.dart';
import '../domain/order_history.dart';

/// "My orders", order detail, cancel, reorder and invoice (`03 §2.10`,
/// `06 §2.6`). Implementations throw `ApiError` (`NOT_FOUND` for an order
/// that isn't the customer's, `INVALID_STATE_TRANSITION` for a cancel
/// outside the window, …).
abstract interface class OrderHistoryRepository {
  /// `GET /orders/?page=`: all the customer's orders, active first.
  Future<OrderPage> listOrders({int page = 1});

  /// `GET /orders/{id}/`.
  Future<OrderDetail> getOrderDetail(int orderId);

  /// `POST /orders/{id}/cancel/ {reason}` (`08` T5/T11). Returns the
  /// cancelled order, with its refund when one was started.
  Future<OrderDetail> cancel(int orderId, CancelReason reason);

  /// `POST /orders/{id}/reorder/`: the server adds what it can to the cart.
  Future<ReorderResult> reorder(int orderId);

  /// `GET /orders/{id}/invoice/`: a signed link to the GST invoice PDF.
  Future<InvoiceLink> invoice(int orderId);
}

/// Staging and prod until the cart is enabled there (S3-B): no orders can
/// exist, so the list is empty and everything else is unavailable.
class UnavailableOrderHistoryRepository implements OrderHistoryRepository {
  const UnavailableOrderHistoryRepository();

  static Never _unavailable() =>
      throw const ApiError(code: ApiErrorCode.serviceUnavailable);

  @override
  Future<OrderPage> listOrders({int page = 1}) async =>
      const OrderPage(items: []);

  @override
  Future<OrderDetail> getOrderDetail(int orderId) async => _unavailable();

  @override
  Future<OrderDetail> cancel(int orderId, CancelReason reason) async =>
      _unavailable();

  @override
  Future<ReorderResult> reorder(int orderId) async => _unavailable();

  @override
  Future<InvoiceLink> invoice(int orderId) async => _unavailable();
}
