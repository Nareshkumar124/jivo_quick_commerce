import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/checkout/domain/checkout_result.dart';
import 'package:customer_app/features/checkout/domain/idempotency_key.dart';
import 'package:customer_app/features/checkout/presentation/checkout_controller.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../cart/cart_fixtures.dart';

/// Records the Idempotency-Key of every `POST /orders/`; [failures] are
/// thrown first, in order.
class _RecordingBackend extends FakeCommerceBackend {
  _RecordingBackend() : super(latency: Duration.zero);

  final keys = <String>[];
  final failures = <Object>[];

  @override
  Future<PlacedOrder> placeOrder(
    PlaceOrderRequest request, {
    required String idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return super.placeOrder(request, idempotencyKey: idempotencyKey);
  }
}

void main() {
  late _RecordingBackend backend;
  late ProviderContainer container;
  late int issued;

  setUp(() async {
    backend = _RecordingBackend();
    issued = 0;
    await backend.setQuantity(
      101,
      2,
      preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
    );
    container = ProviderContainer(
      overrides: [
        cartRepositoryProvider.overrideWithValue(backend),
        orderRepositoryProvider.overrideWithValue(backend),
        paymentLauncherProvider.overrideWithValue(
          FakePaymentLauncher(choose: (_) async => FakePaymentChoice.succeed),
        ),
        analyticsProvider.overrideWithValue(const NoopAnalyticsClient()),
        idempotencyKeyProvider.overrideWithValue(() => 'key-${++issued}'),
        cartAvailableProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
  });

  CheckoutController checkout() => container.read(checkoutProvider.notifier);

  Future<void> place() =>
      checkout().placeOrder(addressId: 1, expectedGrandTotal: '503.00');

  test(
    'an unknown outcome keeps the key, so a retry is the same order',
    () async {
      backend.failures.add(const ApiError(code: ApiErrorCode.timeout));
      await place();
      expect(
        container.read(checkoutProvider).error?.code,
        ApiErrorCode.timeout,
      );

      checkout().acknowledge();
      await place();
      expect(backend.keys, ['key-1', 'key-1']);
      expect(container.read(checkoutProvider).result, isA<OrderConfirmed>());
    },
  );

  test('after an unknown outcome, a changed request gets a new key', () async {
    backend.failures.add(const ApiError(code: ApiErrorCode.network));
    await place();
    checkout()
      ..acknowledge()
      ..selectMethod(PaymentMethod.cod); // a different order now
    await place();
    expect(backend.keys, ['key-1', 'key-2']);
  });

  test('the contract\'s pending-order 409 offers that order', () async {
    backend.failures.add(
      ApiError.tryParseEnvelope(
        contractExample('orders_create/409/PAYMENTPENDINGORDEREXISTS'),
        statusCode: 409,
      )!,
    );
    await place();
    final state = container.read(checkoutProvider);
    expect(state.pendingOrderId, 5012);
    expect(state.error, isNull);
    expect(state.busy, isFalse);
  });

  test('a definite answer retires the key', () async {
    backend.failures.add(
      const ApiError(code: ApiErrorCode.priceChanged, statusCode: 409),
    );
    await place();
    checkout().acknowledge();
    await place();
    expect(backend.keys, ['key-1', 'key-2']);

    checkout().acknowledge();
    await place(); // a new order after a success gets a new key too
    expect(backend.keys.last, 'key-3');
  });

  test('a second tap while placing is ignored', () async {
    final first = place();
    final second = place();
    await Future.wait([first, second]);
    expect(backend.keys, hasLength(1));
    expect(backend.orders, hasLength(1));
  });

  test('success only with a server-confirmed order', () async {
    checkout().selectMethod(PaymentMethod.online);
    await place();
    final result = container.read(checkoutProvider).result;
    expect(result, isA<OrderConfirmed>());
    expect(result!.order.status, OrderStatus.placed);
    expect(container.read(checkoutProvider).busy, isFalse);
  });

  test('the result is published before the emptied cart reloads', () async {
    container.read(cartProvider);
    await pumpEventQueue();
    bool? cartEmptyAtResult;
    container.listen(checkoutProvider.select((s) => s.result), (_, result) {
      if (result != null) {
        cartEmptyAtResult = container.read(cartProvider).snapshot.isEmpty;
      }
    });
    checkout().selectMethod(PaymentMethod.cod);
    await place();
    // Checkout navigates away while it still shows the cart, then the
    // cart reloads empty (the server cleared it, `08` T2).
    expect(cartEmptyAtResult, isFalse);
    expect(container.read(cartProvider).snapshot.isEmpty, isTrue);
  });

  test('keys are random v4 UUIDs', () {
    final key = newIdempotencyKey();
    expect(
      key,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(newIdempotencyKey(), isNot(key));
  });
}
