import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' as api;
import 'package:jivo_core/jivo_core.dart';

import '../../addresses/domain/saved_address.dart';
import '../../../shared/formatting/formatters.dart';
import '../../cart/data/api_cart_repository.dart' show billFromApi, cartFromApi;
import '../domain/order.dart';
import '../domain/order_history.dart';
import 'api_order_repository.dart' show paymentMethodFromApi;
import 'order_history_repository.dart';

/// Order history on the generated client (`06 §2.6`, Phase 4 contract):
/// list, detail (timeline, cancellation, refunds, invoice flag), cancel,
/// reorder and invoice.
class ApiOrderHistoryRepository implements OrderHistoryRepository {
  ApiOrderHistoryRepository(this._api, this._storeId);

  final api.JivoApi _api;

  /// The serving store (`X-Store-Id` on reorder: the cart is per store).
  final int? Function() _storeId;

  int get _store =>
      _storeId() ??
      (throw const ApiError(code: ApiErrorCode.storeNotFound, statusCode: 404));

  static const pageSize = 20;

  api.OrdersApi get _orders => _api.getOrdersApi();

  @override
  Future<OrderPage> listOrders({int page = 1}) => _guard(() async {
    final result = (await _orders.ordersList(
      page: page,
      pageSize: pageSize,
    )).data!;
    return OrderPage(
      items: [for (final row in result.results) orderListItemFromApi(row)],
      nextPage: result.next == null ? null : page + 1,
    );
  });

  @override
  Future<OrderDetail> getOrderDetail(int orderId) => _guard(
    () async =>
        orderDetailFromApi((await _orders.ordersRetrieve(id: orderId)).data!),
  );

  @override
  Future<OrderDetail> cancel(int orderId, CancelReason reason) =>
      _guard(() async {
        final order = (await _orders.ordersCancel(
          id: orderId,
          orderCancelRequest: api.OrderCancelRequest(
            reason: api.CancelReasonEnum.values.firstWhere(
              (r) => r.value == reason.wireValue,
              orElse: () => api.CancelReasonEnum.OTHER,
            ),
          ),
        )).data!;
        return orderDetailFromApi(order);
      });

  /// Idempotent: the server adds what is missing and reports the rest.
  @override
  Future<ReorderResult> reorder(int orderId) => _guard(() async {
    final result = (await _orders.ordersReorder(
      id: orderId,
      xStoreId: _store,
    )).data!;
    final unavailable = [
      for (final issue in result.unavailable)
        ReorderSkippedItem(
          variantId: issue.variantId,
          productName: issue.productName,
          variantName: issue.variantName,
          reason: ReorderSkipReason.fromWire(issue.reason.value),
          requestedQuantity: issue.requestedQuantity,
          addedQuantity: issue.addedQuantity,
        ),
    ];
    return ReorderResult(
      unavailable: unavailable,
      cart: cartFromApi(result.cart),
      addedCount: result.addedCount,
    );
  });

  /// 409 unless the order is DELIVERED; 503 when the PDF can't be made.
  /// A `url` that doesn't parse throws [FormatException].
  @override
  Future<InvoiceLink> invoice(int orderId) => _guard(() async {
    final invoice = (await _orders.ordersInvoice(id: orderId)).data!;
    return InvoiceLink(
      url: Uri.parse(invoice.url),
      expiresAt: invoice.expiresAt,
      number: invoice.invoiceNumber,
    );
  });
}

/// `OrderSummary` as a list row.
OrderListItem orderListItemFromApi(api.OrderSummary s) => OrderListItem(
  id: s.id,
  number: s.orderNumber,
  status: OrderStatus.fromWire(s.status.value),
  paymentMethod: paymentMethodFromApi(s.paymentMethod),
  paymentStatus: PaymentStatus.fromWire(s.paymentStatus.value),
  storeName: s.store.name,
  itemCount: s.itemCount,
  imageUrls: [
    for (final image in s.images)
      if (image.thumbnail.isNotEmpty) image.thumbnail,
  ],
  grandTotal: s.grandTotal,
  createdAt: s.createdAt,
  placedAt: s.placedAt,
  etaAt: s.etaAt,
  canRetryPayment: s.canRetryPayment,
);

/// `Order` as the detail screen's order.
OrderDetail orderDetailFromApi(api.Order o) => OrderDetail(
  id: o.id,
  number: o.orderNumber,
  status: OrderStatus.fromWire(o.status.value),
  paymentMethod: paymentMethodFromApi(o.paymentMethod),
  paymentStatus: PaymentStatus.fromWire(o.paymentStatus.value),
  storeName: o.store.name,
  lines: [
    for (final line in o.items)
      OrderLineItem(
        variantId: line.variantId,
        productId: line.productId,
        productName: line.productName,
        variantName: line.variantName,
        imageUrl: line.image?.thumbnail,
        mrp: line.mrp,
        sellingPrice: line.sellingPrice,
        quantity: line.quantity,
        lineMrpTotal: line.lineMrpTotal,
        lineTotal: line.lineTotal,
        quantityUnavailable: line.quantityUnavailable,
      ),
  ],
  itemCount: o.itemCount,
  bill: billFromApi(o.bill),
  couponCode: o.couponCode == null || o.couponCode!.isEmpty
      ? null
      : o.couponCode,
  address: _address(o.address),
  createdAt: o.createdAt,
  placedAt: o.placedAt,
  etaAt: o.etaAt,
  paymentExpiresAt: o.paymentExpiresAt,
  canCancel: o.canCancel,
  canRetryPayment: o.canRetryPayment,
  history: [
    for (final entry in o.timeline)
      OrderStatusEvent(
        status: OrderStatus.fromWire(entry.status.value),
        at: entry.at,
      ),
  ],
  refunds: [
    for (final r in o.refunds)
      OrderRefund(
        amount: r.amount,
        status: RefundStatus.fromWire(r.status.value),
        createdAt: r.createdAt,
        processedAt: r.processedAt,
      ),
  ],
  amountRefunded: isZeroAmount(o.amountRefunded) ? null : o.amountRefunded,
  invoiceAvailable: o.canDownloadInvoice,
  cancellation: switch (o.cancellation) {
    null => null,
    final c => OrderCancellationInfo(
      reason: c.reason.value,
      message: c.message,
      cancelledBy: switch (c.cancelledBy) {
        api.CancelledByEnum.customer => CancelledBy.customer,
        api.CancelledByEnum.store => CancelledBy.store,
        api.CancelledByEnum.rider => CancelledBy.rider,
        api.CancelledByEnum.ops => CancelledBy.ops,
        api.CancelledByEnum.system => CancelledBy.system,
        _ => CancelledBy.unknown,
      },
      cancelledAt: c.cancelledAt,
    ),
  },
);

OrderAddressSnapshot _address(api.OrderAddress a) => OrderAddressSnapshot(
  label: switch (a.label) {
    api.AddressLabelEnum.home => AddressLabel.home,
    api.AddressLabelEnum.work => AddressLabel.work,
    _ => AddressLabel.other,
  },
  customLabel: a.customLabel.trim().isEmpty ? null : a.customLabel.trim(),
  receiverName: a.receiverName,
  receiverPhone: a.receiverPhone,
  text: [
    a.house,
    a.buildingStreet,
    a.landmark,
    a.area,
    a.city,
    a.pincode,
  ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(', '),
);

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}
