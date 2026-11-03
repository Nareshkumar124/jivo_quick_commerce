import 'dart:async';

import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/checkout/presentation/payment_retry_controller.dart';
import 'package:customer_app/features/location/presentation/delivery_controller.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../cart/cart_fixtures.dart';

/// Each `getOrder` waits for the test to answer it.
class _HeldReads extends FakeCommerceBackend {
  _HeldReads() : super(latency: Duration.zero);

  final reads = <Completer<PlacedOrder>>[];

  @override
  Future<PlacedOrder> getOrder(int orderId) {
    final read = Completer<PlacedOrder>();
    reads.add(read);
    return read.future;
  }
}

PlacedOrder _order({required bool canRetry}) => PlacedOrder(
  id: 1001,
  number: 'JV-261103-001001',
  status: OrderStatus.paymentPending,
  paymentMethod: PaymentMethod.online,
  grandTotal: '503.00',
  canCancel: true,
  canRetryPayment: canRetry,
);

/// A store scope the test moves by hand.
class _Scope extends Notifier<(int?, int)> {
  @override
  (int?, int) build() => (null, 0);

  void move((int?, int) next) => state = next;
}

final _scope = NotifierProvider<_Scope, (int?, int)>(_Scope.new);

void main() {
  test('a slow, older status read never overwrites a newer one', () async {
    final backend = _HeldReads();
    final container = ProviderContainer(
      overrides: [orderRepositoryProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    final provider = paymentRetryProvider(1001);
    final keepAlive = container.listen(provider, (_, _) {});
    addTearDown(keepAlive.close);

    await pumpEventQueue(); // the screen's first read is in flight
    final newer = container.read(provider.notifier).reload();
    await pumpEventQueue();
    expect(backend.reads, hasLength(2));

    // The newer read answers first: the server no longer allows retry.
    backend.reads[1].complete(_order(canRetry: false));
    await newer;
    expect(container.read(provider).order!.canRetryPayment, isFalse);

    // The older read arrives late with the stale "can retry": ignored.
    backend.reads[0].complete(_order(canRetry: true));
    await pumpEventQueue();
    final state = container.read(provider);
    expect(state.order!.canRetryPayment, isFalse);
    expect(state.canRetry, isFalse);
    expect(state.loading, isFalse);
  });

  test('a store change reloads a built cart once, and builds none', () async {
    final stub = StubCartRepository(cartSnapshot());
    final container = ProviderContainer(
      overrides: [
        cartRepositoryProvider.overrideWithValue(stub),
        storeScopeProvider.overrideWith((ref) => ref.watch(_scope)),
      ],
    );
    addTearDown(container.dispose);
    // Listened to, as the app widget watches it (Riverpod pauses providers
    // nobody listens to).
    final sync = container.listen(cartStoreSyncProvider, (_, _) {});
    addTearDown(sync.close);
    int loads() => stub.calls.where((c) => c.startsWith('load')).length;

    // Nobody reads the cart yet: a store change sends nothing.
    container.read(_scope.notifier).move((7, 0));
    await pumpEventQueue();
    expect(loads(), 0);

    // Built: its own first load, once.
    container.read(cartProvider);
    await pumpEventQueue();
    expect(loads(), 1);

    // The store changes: exactly one more load.
    container.read(_scope.notifier).move((8, 0));
    await pumpEventQueue();
    expect(loads(), 2);
  });
}
