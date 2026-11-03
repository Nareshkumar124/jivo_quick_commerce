import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' as api;
import 'package:jivo_core/jivo_core.dart';

import '../domain/order.dart';
import 'order_repository.dart';

/// Orders and payments on the generated client (`06 §2.6`).
class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._api, this._storeId);

  final api.JivoApi _api;

  /// The store the cart is priced at (`X-Store-Id` on `POST /orders/`).
  final int? Function() _storeId;

  /// Rows read per page when looking an order up in the list.
  static const listPageSize = 100;

  api.OrdersApi get _orders => _api.getOrdersApi();

  int get _store =>
      _storeId() ??
      (throw const ApiError(code: ApiErrorCode.storeNotFound, statusCode: 404));

  @override
  Future<PlacedOrder> placeOrder(
    PlaceOrderRequest request, {
    required String idempotencyKey,
  }) => _guard(() async {
    final placement = (await _orders.ordersCreate(
      idempotencyKey: idempotencyKey,
      xStoreId: _store,
      orderCreateRequest: api.OrderCreateRequest(
        addressId: request.addressId,
        paymentMethod: _methodToApi(request.paymentMethod),
        expectedGrandTotal: request.expectedGrandTotal,
      ),
    )).data!;
    return placementFromApi(placement);
  });

  @override
  Future<PlacedOrder> verifyPayment(PaymentProof proof) => _guard(() async {
    final order = (await _api.getPaymentsApi().paymentsRazorpayVerify(
      paymentVerifyRequest: api.PaymentVerifyRequest(
        orderId: proof.orderId,
        razorpayOrderId: proof.razorpayOrderId,
        razorpayPaymentId: proof.razorpayPaymentId,
        razorpaySignature: proof.razorpaySignature,
      ),
    )).data!;
    return orderFromApi(order);
  });

  @override
  Future<PlacedOrder> retryPayment(
    int orderId, {
    required String idempotencyKey,
  }) => _guard(() async {
    final placement = (await _orders.ordersRetryPayment(
      idempotencyKey: idempotencyKey,
      id: orderId,
    )).data!;
    return placementFromApi(placement);
  });

  @override
  Future<PlacedOrder> cancelOrder(
    int orderId, {
    required CancelReason reason,
  }) => _guard(() async {
    final order = (await _orders.ordersCancel(
      id: orderId,
      orderCancelRequest: api.OrderCancelRequest(reason: _reasonToApi(reason)),
    )).data!;
    return orderFromApi(order);
  });

  /// TODO(api): `GET /orders/{id}/` (backend P3 R2a) is not in the schema
  /// yet. Until it is, the order is found in the generated order list:
  /// active orders first, then past ones.
  @override
  Future<PlacedOrder> getOrder(int orderId) => _guard(() async {
    for (final status in const ['active', 'past']) {
      final page = (await _orders.ordersList(
        status: status,
        pageSize: listPageSize,
      )).data!;
      for (final row in page.results) {
        if (row.id == orderId) return summaryFromApi(row);
      }
    }
    throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
  });

  @override
  Future<List<PlacedOrder>> activeOrders() => _guard(() async {
    final page = (await _orders.ordersList(
      status: 'active',
      pageSize: listPageSize,
    )).data!;
    return [for (final row in page.results) summaryFromApi(row)];
  });
}

/// `OrderPlacement`: the order plus, while it awaits payment, Razorpay's
/// checkout options.
PlacedOrder placementFromApi(api.OrderPlacement p) =>
    orderFromApi(p.order, razorpay: p.razorpay);

/// `Order` as the app's [PlacedOrder].
PlacedOrder orderFromApi(api.Order o, {api.RazorpayCheckout? razorpay}) =>
    PlacedOrder(
      id: o.id,
      number: o.orderNumber,
      status: OrderStatus.fromWire(o.status.value),
      paymentMethod:
          paymentMethodFromApi(o.paymentMethod) ?? PaymentMethod.online,
      grandTotal: o.bill.grandTotal,
      etaAt: o.etaAt,
      paymentExpiresAt: o.paymentExpiresAt,
      canCancel: o.canCancel,
      canRetryPayment: o.canRetryPayment,
      razorpay: razorpay == null ? null : _checkout(razorpay),
    );

/// `OrderSummary` (a list row) as the app's [PlacedOrder].
PlacedOrder summaryFromApi(api.OrderSummary s) {
  final status = OrderStatus.fromWire(s.status.value);
  return PlacedOrder(
    id: s.id,
    number: s.orderNumber,
    status: status,
    paymentMethod:
        paymentMethodFromApi(s.paymentMethod) ?? PaymentMethod.online,
    grandTotal: s.grandTotal,
    etaAt: s.etaAt,
    paymentExpiresAt: s.paymentExpiresAt,
    // TODO(api): `OrderSummary` has no `can_cancel`; in Phase 3 the server
    // allows a cancel exactly in PAYMENT_PENDING (`06 §2.6`). Use the
    // order's own flag once `GET /orders/{id}/` exists.
    canCancel: status == OrderStatus.paymentPending,
    canRetryPayment: s.canRetryPayment,
  );
}

/// `PaymentMethodEnum`, or null for a method this build doesn't know.
PaymentMethod? paymentMethodFromApi(api.PaymentMethodEnum m) => switch (m) {
  api.PaymentMethodEnum.ONLINE => PaymentMethod.online,
  api.PaymentMethodEnum.COD => PaymentMethod.cod,
  _ => null,
};

api.PaymentMethodEnum _methodToApi(PaymentMethod m) => switch (m) {
  PaymentMethod.online => api.PaymentMethodEnum.ONLINE,
  PaymentMethod.cod => api.PaymentMethodEnum.COD,
};

api.CancelReasonEnum _reasonToApi(CancelReason r) => switch (r) {
  CancelReason.changePaymentMethod =>
    api.CancelReasonEnum.CHANGE_PAYMENT_METHOD,
  CancelReason.paymentProblem => api.CancelReasonEnum.PAYMENT_PROBLEM,
  CancelReason.orderedByMistake => api.CancelReasonEnum.ORDERED_BY_MISTAKE,
  CancelReason.changedMind => api.CancelReasonEnum.CHANGED_MIND,
  CancelReason.deliveryTooSlow => api.CancelReasonEnum.DELIVERY_TOO_SLOW,
  CancelReason.other => api.CancelReasonEnum.OTHER,
};

RazorpayCheckout _checkout(api.RazorpayCheckout r) => RazorpayCheckout(
  keyId: r.keyId,
  orderId: r.orderId,
  amountPaise: r.amount,
  currency: r.currency,
  name: r.name,
  description: r.description,
  prefillName: r.prefill.name.isEmpty ? null : r.prefill.name,
  prefillEmail: r.prefill.email.isEmpty ? null : r.prefill.email,
  prefillContact: r.prefill.contact.isEmpty ? null : r.prefill.contact,
  expiresAt: r.expiresAt,
  timeoutSeconds: r.timeoutSeconds,
);

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}
