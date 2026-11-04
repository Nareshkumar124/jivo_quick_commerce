import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:customer_app/features/orders/data/api_order_history_repository.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../../helpers/fake_http.dart';

/// `ApiOrderHistoryRepository` on the generated client, answered with the
/// contract's own examples (list, detail and cancel exist since Phase 3).
void main() {
  late FakeHttp http;
  late ApiOrderHistoryRepository repository;
  late Object? Function(({String method, String path, String query}) r) answer;

  setUp(() {
    answer = (_) => null;
    http = FakeHttp((request) {
      final body = answer((
        method: request.method,
        path: request.uri.path,
        query: request.uri.query,
      ));
      if (body is (int, Object?)) return body;
      return (200, body);
    });
    repository = ApiOrderHistoryRepository(http.api(), () => 7);
  });

  test('GET /orders/: all orders, page and page size; rows mapped', () async {
    answer = (_) => contractExample('orders_list/200/ActiveOrders');
    final page = await repository.listOrders(page: 2);

    final sent = http.requests.single;
    expect(sent.method, 'GET');
    expect(sent.uri.path, '/api/v1/orders/');
    expect(sent.uri.queryParameters, {'page': '2', 'page_size': '20'});
    expect(sent.uri.queryParameters.containsKey('status'), isFalse);

    expect(page.nextPage, isNull);
    final first = page.items.first;
    expect(first.id, 5012);
    expect(first.number, 'JV-261103-000123');
    expect(first.status, OrderStatus.paymentPending);
    expect(first.isActive, isTrue);
    expect(first.paymentMethod, PaymentMethod.online);
    expect(first.paymentStatus, PaymentStatus.pending);
    expect(first.storeName, 'Jivo Sector 14, Gurugram');
    expect(first.itemCount, 3);
    expect(first.grandTotal, '753.00');
    expect(first.imageUrls.first, endsWith('canola-1l-256.webp'));
  });

  test('a next link means another page', () async {
    final body = Map<String, Object?>.of(
      contractExample('orders_list/200/PastOrders')! as Map<String, Object?>,
    )..['next'] = 'http://api/v1/orders/?page=2';
    answer = (_) => body;
    final page = await repository.listOrders();
    expect(page.nextPage, 2);
    expect(page.items, isNotEmpty);
    expect(page.items.every((o) => !o.isActive), isTrue);
  });

  test('no orders: an empty page', () async {
    answer = (_) => contractExample('orders_list/200/NoOrders');
    final page = await repository.listOrders();
    expect(page.items, isEmpty);
  });

  test('a page past the end is NOT_FOUND', () async {
    answer = (_) => (404, contractExample('orders_list/404/PAGENOTFOUND'));
    await expectLater(
      repository.listOrders(page: 9),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
      ),
    );
  });

  test('GET /orders/{id}/: lines, server bill, address snapshot', () async {
    answer = (_) => contractExample('orders_retrieve/200/AwaitingPayment');
    final order = await repository.getOrderDetail(5012);

    expect(http.requests.single.uri.path, '/api/v1/orders/5012/');
    expect(order.status, OrderStatus.paymentPending);
    expect(order.canRetryPayment, isTrue);
    expect(order.lines.first.productName, 'Jivo Cold Pressed Canola Oil');
    expect(order.lines.first.quantity, 2);
    expect(order.lines.first.lineTotal, '558.00');
    expect(order.bill.grandTotal, '753.00');
    expect(order.address, isNotNull);
    expect(order.address!.label, isA<AddressLabel>());
    expect(order.address!.text, isNotEmpty);
    expect(order.invoiceAvailable, isFalse);
    expect(order.refunds, isEmpty);
    expect(order.amountRefunded, isNull);
    expect(order.cancellation, isNull);
  });

  test('P4 detail: timeline, unavailable units and a pending refund', () async {
    answer = (_) => contractExample(
      'orders_retrieve/200/Packing,AnItemUnavailable(refundPending)',
    );
    final order = await repository.getOrderDetail(5012);
    expect(order.status, OrderStatus.packing);
    expect(order.canCancel, isFalse);
    expect(order.needsSupportToCancel, isTrue);
    expect(order.history.map((e) => e.status), contains(OrderStatus.accepted));
    expect(order.lines.first.quantityUnavailable, 1);
    expect(order.paymentStatus, PaymentStatus.refundPending);
    expect(order.refunds.single.amount, '279.00');
    expect(order.refunds.single.status, RefundStatus.pending);
    // "0.00" refunded so far is no amount.
    expect(order.amountRefunded, isNull);
    final steps = buildTimeline(order);
    expect(steps[2].state, TimelineStepState.current);
    expect(steps[1].at, DateTime.utc(2026, 11, 3, 6, 32, 40));
  });

  test('P4 detail: delivered with an invoice; store-cancelled COD', () async {
    answer = (_) =>
        contractExample('orders_retrieve/200/Delivered,InvoiceAvailable');
    final delivered = await repository.getOrderDetail(5012);
    expect(delivered.status, OrderStatus.delivered);
    expect(delivered.invoiceAvailable, isTrue);
    expect(delivered.canReorder, isTrue);

    answer = (_) =>
        contractExample('orders_retrieve/200/CancelledByTheStore(COD)');
    final cancelled = await repository.getOrderDetail(5011);
    expect(cancelled.cancellation!.cancelledBy, CancelledBy.store);
    expect(cancelled.cancellation!.reason, 'ITEMS_UNAVAILABLE');
    expect(
      cancelled.cancellation!.message,
      'Items are not available at the store',
    );
    expect(buildTimeline(cancelled).last.ending, OrderStatus.cancelled);
  });

  test('POST /orders/{id}/cancel/ sends the reason', () async {
    answer = (_) =>
        contractExample('orders_cancel/200/CancelledAfterPaying:Refunded(T11)');
    final order = await repository.cancel(5012, CancelReason.changedMind);

    final sent = http.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/orders/5012/cancel/');
    expect(http.body(0)['reason'], 'CHANGED_MIND');
    expect(order.status, OrderStatus.cancelled);
    expect(order.paymentStatus, PaymentStatus.refunded);
    expect(order.amountRefunded, '753.00');
    expect(order.refunds.single.status, RefundStatus.processed);
    expect(order.cancellation!.cancelledBy, CancelledBy.customer);
  });

  test('cancel outside the window is INVALID_STATE_TRANSITION', () async {
    answer = (_) =>
        (409, contractExample('orders_cancel/409/INVALIDSTATETRANSITION'));
    await expectLater(
      repository.cancel(5012, CancelReason.other),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.invalidStateTransition,
        ),
      ),
    );
  });

  test('POST /orders/{id}/reorder/ sends X-Store-Id; reports issues', () async {
    answer = (_) => contractExample('orders_reorder/200/SomeItemsUnavailable');
    final result = await repository.reorder(4870);

    final sent = http.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/orders/4870/reorder/');
    expect('${sent.headers['X-Store-Id']}', '7');
    expect(result.addedAll, isFalse);
    expect(result.cart, isNotNull);
    final out = result.unavailable.first;
    expect(out.reason, ReorderSkipReason.outOfStock);
    expect(out.productName, 'Jivo Chia Seeds');
    expect(out.addedQuantity, 0);
    final limited = result.unavailable.last;
    expect(limited.reason, ReorderSkipReason.quantityReduced);
    expect(limited.requestedQuantity, 3);
    expect(limited.addedQuantity, 2);
    expect(result.addedNothing(3), isFalse);
    expect(result.addedNothing(1), isTrue);
  });

  test('reorder with everything added', () async {
    answer = (_) => contractExample('orders_reorder/200/EverythingAdded');
    final result = await repository.reorder(4870);
    expect(result.addedAll, isTrue);
    expect(result.cart!.isEmpty, isFalse);
  });

  test('reorder needs a store', () async {
    repository = ApiOrderHistoryRepository(http.api(), () => null);
    await expectLater(
      repository.reorder(1),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.storeNotFound,
        ),
      ),
    );
    expect(http.requests, isEmpty);
  });

  test('GET /orders/{id}/invoice/: the signed link', () async {
    answer = (_) => contractExample('orders_invoice/200/Invoice');
    final link = await repository.invoice(5012);
    expect(http.requests.single.uri.path, '/api/v1/orders/5012/invoice/');
    expect(link.number, 'GGN01/26-27/000122');
    expect(link.url.path, endsWith('.pdf'));
    expect(link.expiresAt, DateTime.utc(2026, 11, 3, 7));
  });

  test('an invoice before delivery is 409', () async {
    answer = (_) =>
        (409, contractExample('orders_invoice/409/INVOICENOTREADY'));
    await expectLater(repository.invoice(5012), throwsA(isA<ApiError>()));
  });
}
