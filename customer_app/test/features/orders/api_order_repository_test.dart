import 'package:customer_app/features/orders/data/api_order_repository.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../../helpers/fake_http.dart';

/// `ApiOrderRepository` on the generated client, answered with the Phase 3
/// contract's own examples.
void main() {
  late FakeHttp http;
  late ApiOrderRepository repository;
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
    repository = ApiOrderRepository(http.api(), () => 7);
  });

  const request = PlaceOrderRequest(
    addressId: 12,
    paymentMethod: PaymentMethod.online,
    expectedGrandTotal: '753.00',
  );

  test('POST /orders/: key, store, body; the fake gateway checkout', () async {
    answer = (_) => (
      201,
      contractExample('orders_create/201/Online,LocalFakeGateway(devOnly)'),
    );
    final order = await repository.placeOrder(
      request,
      idempotencyKey: '8b6f1f0e-1c2d-4e5f-9a7b-0c1d2e3f4a5b',
    );

    final sent = http.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/orders/');
    expect(
      sent.headers['Idempotency-Key'],
      '8b6f1f0e-1c2d-4e5f-9a7b-0c1d2e3f4a5b',
    );
    expect('${sent.headers['X-Store-Id']}', '7');
    expect(http.body(0), {
      'address_id': 12,
      'payment_method': 'ONLINE',
      'expected_grand_total': '753.00',
    });

    expect(order.id, 5012);
    expect(order.number, 'JV-261103-000123');
    expect(order.status, OrderStatus.paymentPending);
    expect(order.grandTotal, '753.00');
    expect(order.canRetryPayment, isTrue);
    expect(order.canCancel, isTrue);
    expect(order.paymentExpiresAt, DateTime.utc(2026, 11, 3, 6, 45));
    final checkout = order.razorpay!;
    expect(checkout.keyId, 'rzp_fake_jivo_local');
    expect(checkout.isFakeGateway, isTrue);
    expect(checkout.orderId, 'order_Nq3uVxY7kL9pQe');
    expect(checkout.amountPaise, 75300);
    expect(checkout.name, 'Jivo');
    expect(checkout.description, 'Order JV-261103-000123');
    expect(checkout.timeoutSeconds, 900);
    expect(checkout.prefillContact, '+919876543210');
  });

  test('COD is placed without a checkout; real keys are not fake', () async {
    answer = (_) => (201, contractExample('orders_create/201/CashOnDelivery'));
    final cod = await repository.placeOrder(request, idempotencyKey: 'k-cod-1');
    expect(cod.status, OrderStatus.placed);
    expect(cod.paymentMethod, PaymentMethod.cod);
    expect(cod.razorpay, isNull);
    expect(cod.etaAt, isNotNull);

    answer = (_) =>
        (201, contractExample('orders_create/201/Online:OpenCheckout'));
    final online = await repository.placeOrder(
      request,
      idempotencyKey: 'k-online-1',
    );
    expect(online.razorpay!.isFakeGateway, isFalse);
  });

  test('errors keep the details the messages use', () async {
    answer = (_) => (409, contractExample('orders_create/409/PRICECHANGED'));
    await expectLater(
      repository.placeOrder(request, idempotencyKey: 'k-1-price'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.priceChanged)
            .having((e) => e.details['grand_total'], 'new', '778.00'),
      ),
    );
    answer = (_) =>
        (409, contractExample('orders_create/409/STOCKUNAVAILABLE'));
    await expectLater(
      repository.placeOrder(request, idempotencyKey: 'k-2-stock'),
      throwsA(
        isA<ApiError>().having(
          (e) => (e.details['items']! as List).length,
          'items',
          2,
        ),
      ),
    );
    answer = (_) =>
        (503, contractExample('orders_create/503/PAYMENTGATEWAYUNAVAILABLE'));
    await expectLater(
      repository.placeOrder(request, idempotencyKey: 'k-3-gateway'),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.serviceUnavailable,
        ),
      ),
    );
  });

  test('verify, retry (with a key) and cancel (with a reason)', () async {
    answer = (r) => switch (r.path) {
      '/api/v1/payments/razorpay/verify/' => contractExample(
        'payments_razorpay_verify/200/Paid',
      ),
      '/api/v1/orders/5012/retry-payment/' => contractExample(
        'orders_retry_payment/200/Retry',
      ),
      _ => contractExample('orders_cancel/200/Cancelled'),
    };
    final paid = await repository.verifyPayment(
      const PaymentProof(
        orderId: 5012,
        razorpayOrderId: 'order_Nq3uVxY7kL9pQe',
        razorpayPaymentId: 'pay_Nq3vA1bC2dE3fG',
        razorpaySignature:
            'bc4bcc84a495aaddc2f52819146edd4d26728c1221e5621f23995c106721c977',
      ),
    );
    expect(paid.status, OrderStatus.placed);
    expect(http.body(0), {
      'order_id': 5012,
      'razorpay_order_id': 'order_Nq3uVxY7kL9pQe',
      'razorpay_payment_id': 'pay_Nq3vA1bC2dE3fG',
      'razorpay_signature':
          'bc4bcc84a495aaddc2f52819146edd4d26728c1221e5621f23995c106721c977',
    });
    expect(http.requests[0].headers.containsKey('Idempotency-Key'), isFalse);

    final retried = await repository.retryPayment(
      5012,
      idempotencyKey: 'retry-key-0001',
    );
    expect(retried.razorpay, isNotNull);
    expect(http.requests[1].headers['Idempotency-Key'], 'retry-key-0001');

    final cancelled = await repository.cancelOrder(
      5012,
      reason: CancelReason.changePaymentMethod,
    );
    expect(cancelled.status, OrderStatus.cancelled);
    expect(http.body(2), {'reason': 'CHANGE_PAYMENT_METHOD'});
  });

  test(
    'active orders from the list; one order from GET /orders/{id}/',
    () async {
      answer = (r) => r.path == '/api/v1/orders/'
          ? contractExample('orders_list/200/ActiveOrders')
          : contractExample('orders_retrieve/200/AwaitingPayment');
      final active = await repository.activeOrders();
      expect(active.first.id, 5012);
      expect(active.first.status, OrderStatus.paymentPending);
      expect(active.first.canRetryPayment, isTrue);
      expect(http.requests.single.uri.queryParameters['status'], 'active');

      final order = await repository.getOrder(5012);
      expect(http.requests.last.method, 'GET');
      expect(http.requests.last.uri.path, '/api/v1/orders/5012/');
      expect(order.number, 'JV-261103-000123');
      expect(order.status, OrderStatus.paymentPending);
      // The server's own flags, not derived from the status.
      expect(order.canCancel, isTrue);
      expect(order.canRetryPayment, isTrue);

      for (final (name, status, retry) in [
        ('PaidOnline', OrderStatus.placed, false),
        ('CashOnDelivery', OrderStatus.placed, false),
        ('CancelledBeforePaying', OrderStatus.cancelled, false),
      ]) {
        answer = (_) => contractExample('orders_retrieve/200/$name');
        final other = await repository.getOrder(5012);
        expect(other.status, status, reason: name);
        expect(other.canRetryPayment, retry, reason: name);
      }

      answer = (_) => (404, contractExample('orders_retrieve/404/NOTFOUND'));
      await expectLater(
        repository.getOrder(999),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'c', ApiErrorCode.notFound),
        ),
      );
    },
  );

  test('an unknown status or method decodes, without a guess', () async {
    final json =
        contractExample('orders_retrieve/200/AwaitingPayment')!
            as Map<String, Object?>;
    json['status'] = 'ON_HOLD';
    json['payment_method'] = 'PAY_LATER';
    json['payment_status'] = 'DISPUTED';
    answer = (_) => json;
    final order = await repository.getOrder(5012);
    expect(order.status, OrderStatus.unknown);
    expect(order.status.isConfirmed, isFalse); // never "success"
    expect(order.paymentMethod, isNull); // not defaulted to ONLINE
  });

  test('a second order while one awaits payment names that order', () async {
    answer = (_) =>
        (409, contractExample('orders_create/409/PAYMENTPENDINGORDEREXISTS'));
    await expectLater(
      repository.placeOrder(request, idempotencyKey: 'k-4-pending'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', ApiErrorCode.invalidStateTransition)
            .having((e) => e.details['pending_order_id'], 'pending', 5012),
      ),
    );
  });
}
