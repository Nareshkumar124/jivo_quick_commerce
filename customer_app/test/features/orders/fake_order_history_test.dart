import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

const canola = CatalogVariant(
  id: 101,
  name: '1 L',
  sellingPrice: '249.00',
  mrp: '299.00',
  stockStatus: StockStatus.inStock,
  orderableQuantity: 10,
  maxQtyPerOrder: 10,
);
const mustard = CatalogVariant(
  id: 501,
  name: '1 L',
  sellingPrice: '189.00',
  mrp: '210.00',
  stockStatus: StockStatus.inStock,
  orderableQuantity: 10,
  maxQtyPerOrder: 10,
);

Matcher apiError(ApiErrorCode code) =>
    throwsA(isA<ApiError>().having((e) => e.code, 'code', code));

/// The fake server's Phase 4 side: list, detail, T11 cancel with the
/// `08 §6.4` refund, reorder with unavailable items, invoice.
void main() {
  late FakeCommerceBackend backend;
  var key = 0;

  setUp(() => backend = FakeCommerceBackend(latency: Duration.zero));

  Future<PlacedOrder> place(PaymentMethod method, {int canolaQty = 2}) async {
    await backend.setQuantity(
      canola.id,
      canolaQty,
      preview: CartLinePreview.of(canola, 'Jivo Canola Oil'),
    );
    await backend.setQuantity(
      mustard.id,
      1,
      preview: CartLinePreview.of(mustard, 'Jivo Mustard Oil'),
    );
    final cart = await backend.load(addressId: 1);
    return backend.placeOrder(
      PlaceOrderRequest(
        addressId: 1,
        paymentMethod: method,
        expectedGrandTotal: cart.bill!.grandTotal,
      ),
      idempotencyKey: 'k${key++}',
    );
  }

  test('detail keeps the lines, the bill and the history', () async {
    final placed = await place(PaymentMethod.cod);
    final order = await backend.getOrderDetail(placed.id);
    expect(order.status, OrderStatus.placed);
    expect(order.paymentStatus, PaymentStatus.codPending);
    expect(order.lines.map((l) => l.quantity), [2, 1]);
    expect(order.lines.first.lineTotal, '498.00');
    expect(order.bill.grandTotal, placed.grandTotal);
    expect(order.history.single.status, OrderStatus.placed);
    expect(order.canCancel, isTrue);
    expect(order.invoiceAvailable, isFalse);
  });

  test('the list puts active orders first and pages', () async {
    backend.historyPageSize = 1;
    final first = await place(PaymentMethod.cod);
    backend.advanceOrder(first.id, OrderStatus.delivered);
    final second = await place(PaymentMethod.cod);

    final page1 = await backend.listOrders();
    expect(page1.items.single.id, second.id);
    expect(page1.nextPage, 2);
    final page2 = await backend.listOrders(page: 2);
    expect(page2.items.single.id, first.id);
    expect(page2.nextPage, isNull);
    expect(() => backend.listOrders(page: 3), apiError(ApiErrorCode.notFound));
  });

  test('T11: a paid online order is refunded in full on cancel', () async {
    final placed = await place(PaymentMethod.online);
    backend.confirmByWebhook(placed.id);
    backend.advanceOrder(placed.id, OrderStatus.accepted);

    final cancelled = await backend.cancel(placed.id, CancelReason.changedMind);
    expect(cancelled.status, OrderStatus.cancelled);
    expect(cancelled.paymentStatus, PaymentStatus.refundPending);
    expect(cancelled.refunds.single.amount, placed.grandTotal);
    expect(cancelled.refunds.single.status, RefundStatus.pending);
    expect(cancelled.amountRefunded, isNull);
    expect(backend.cancelReasonOf(placed.id), CancelReason.changedMind);

    backend.settleRefunds(placed.id);
    final refunded = await backend.getOrderDetail(placed.id);
    expect(refunded.paymentStatus, PaymentStatus.refunded);
    expect(refunded.refunds.single.status, RefundStatus.processed);
    expect(refunded.amountRefunded, placed.grandTotal);
  });

  test('COD cancel needs no refund; packing is past the window', () async {
    final cod = await place(PaymentMethod.cod);
    final cancelled = await backend.cancel(cod.id, CancelReason.other);
    expect(cancelled.refunds, isEmpty);
    expect(cancelled.canCancel, isFalse);

    final packing = await place(PaymentMethod.cod);
    backend
      ..advanceOrder(packing.id, OrderStatus.accepted)
      ..advanceOrder(packing.id, OrderStatus.packing);
    expect((await backend.getOrder(packing.id)).canCancel, isFalse);
    expect(
      () => backend.cancel(packing.id, CancelReason.other),
      apiError(ApiErrorCode.invalidStateTransition),
    );
  });

  test('a store cancel of a paid order is refunded too (T12)', () async {
    final placed = await place(PaymentMethod.online);
    backend.confirmByWebhook(placed.id);
    backend.advanceOrder(placed.id, OrderStatus.cancelled);
    final order = await backend.getOrderDetail(placed.id);
    expect(order.paymentStatus, PaymentStatus.refundPending);
    expect(order.refunds, hasLength(1));
  });

  test('reorder adds what it can and reports the rest', () async {
    final placed = await place(PaymentMethod.cod, canolaQty: 3);
    backend.advanceOrder(placed.id, OrderStatus.delivered);
    backend.stock[canola.id] = 2;
    backend.stock[mustard.id] = 0;

    final result = await backend.reorder(placed.id);
    expect(result.addedNothing(2), isFalse);
    expect(result.addedAll, isFalse);
    final reduced = result.unavailable.firstWhere(
      (i) => i.variantId == canola.id,
    );
    expect(reduced.reason, ReorderSkipReason.quantityReduced);
    expect(reduced.addedQuantity, 2);
    expect(reduced.requestedQuantity, 3);
    expect(
      result.unavailable.firstWhere((i) => i.variantId == mustard.id).reason,
      ReorderSkipReason.outOfStock,
    );
    expect(result.cart!.quantityOf(canola.id), 2);
    expect((await backend.load()).quantityOf(canola.id), 2);
  });

  test('reorder reports discontinued items; all added otherwise', () async {
    final placed = await place(PaymentMethod.cod);
    backend.advanceOrder(placed.id, OrderStatus.delivered);
    backend.discontinued.add(mustard.id);
    final partial = await backend.reorder(placed.id);
    expect(partial.unavailable.single.reason, ReorderSkipReason.discontinued);

    await backend.clear();
    backend.discontinued.clear();
    final full = await backend.reorder(placed.id);
    expect(full.addedAll, isTrue);
    expect(full.unavailable, isEmpty);
  });

  test('the invoice exists once delivered', () async {
    final placed = await place(PaymentMethod.cod);
    await expectLater(
      backend.invoice(placed.id),
      apiError(ApiErrorCode.notFound),
    );
    backend.advanceOrder(placed.id, OrderStatus.delivered);
    final order = await backend.getOrderDetail(placed.id);
    expect(order.invoiceAvailable, isTrue);
    expect(order.paymentStatus, PaymentStatus.codCollected);
    final link = await backend.invoice(placed.id);
    expect(link.url.path, endsWith('${placed.number}.pdf'));
  });

  test('demo orders: delivered, refunded and packing', () async {
    backend.seedDemoOrders();
    final page = await backend.listOrders();
    expect(page.items.map((o) => o.status), [
      OrderStatus.packing,
      OrderStatus.cancelled,
      OrderStatus.delivered,
    ]);
    expect((await backend.load()).isEmpty, isTrue);
    final coupons = await backend.coupons();
    expect(coupons.any((c) => c.code == 'FIRSTORDER'), isTrue);
  });
}
