import 'dart:async';

import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../catalog/catalog_fixtures.dart';
import 'cart_fixtures.dart';

void main() {
  late FakeCommerceBackend repository;
  late ProviderContainer container;

  ProviderContainer containerWith(CartRepository repo) {
    final c = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    repository = FakeCommerceBackend(latency: Duration.zero);
    container = containerWith(repository);
  });

  CartController cart() => container.read(cartProvider.notifier);

  /// The calls that change the cart (the controller also loads on start).
  List<String> writes(StubCartRepository stub) =>
      stub.calls.where((call) => !call.startsWith('load')).toList();
  CartState state() => container.read(cartProvider);

  test('increment and decrement go through the repository', () async {
    final oil = variant();
    await cart().increment(oil, productName: 'Jivo Canola Oil');
    await cart().increment(oil);
    expect(state().quantityOf(101), 2);
    expect(state().snapshot.itemCount, 2);
    expect(state().snapshot.lines.single.productName, 'Jivo Canola Oil');

    await cart().decrement(oil);
    await cart().decrement(oil);
    await cart().decrement(oil); // already 0: no call
    expect(state().snapshot.isEmpty, isTrue);
    expect((await repository.load()).isEmpty, isTrue);
  });

  test("caps at the server's orderable_quantity", () async {
    expect(variant(orderable: 3).maxSelectable, 3);
    expect(
      variant(status: StockStatus.outOfStock, orderable: 0).inStock,
      isFalse,
    );

    final scarce = variant(orderable: 1);
    await cart().increment(scarce);
    await expectLater(
      cart().increment(scarce),
      throwsA(isA<CartLimitException>().having((e) => e.max, 'max', 1)),
    );
    await expectLater(
      cart().increment(
        variant(id: 9, status: StockStatus.outOfStock, orderable: 0),
      ),
      throwsA(isA<CartLimitException>()),
    );
    expect(state().quantityOf(101), 1);
  });

  test('the state holds the server cart as sent, never a local sum', () async {
    final stub = StubCartRepository(cartSnapshot());
    final c = containerWith(stub);
    await c.read(cartProvider.notifier).refresh(addressId: 1);
    final snapshot = c.read(cartProvider).snapshot;
    expect(snapshot.bill!.grandTotal, '999.00');
    expect(snapshot.itemTotal, '498.00');
    expect(stub.calls, contains('load:1'));
  });

  test('clear empties the cart', () async {
    await cart().increment(variant());
    await cart().increment(variant(id: 7));
    await cart().clear();
    expect(state().snapshot.isEmpty, isTrue);
  });

  test('a failed change keeps the old quantity and clears pending', () async {
    repository.failNext = Exception('boom');
    await expectLater(cart().increment(variant()), throwsException);
    expect(state().quantityOf(101), 0);
    expect(state().isPending(101), isFalse);
  });

  test('a failed load is kept for the error state, not thrown', () async {
    final stub = StubCartRepository(cartSnapshot())
      ..loadError = const ApiError(code: ApiErrorCode.network);
    final c = containerWith(stub);
    // The load the controller starts on its own fails.
    c.read(cartProvider);
    await pumpEventQueue();
    final s = c.read(cartProvider);
    expect(s.load, CartLoad.failed);
    expect(s.loadError, isA<ApiError>());

    stub.loadError = null;
    await c.read(cartProvider.notifier).refresh();
    expect(c.read(cartProvider).load, CartLoad.ready);
    expect(c.read(cartProvider).loadError, isNull);
  });

  test('a slow older answer never overwrites a newer one', () async {
    final stub = StubCartRepository(cartSnapshot());
    final c = containerWith(stub);
    final controller = c.read(cartProvider.notifier);
    await controller.refresh();

    // The first change is held; a second (other variant) answers at once.
    final held = Completer<void>();
    stub
      ..gate = held
      ..snapshot = cartSnapshot(lines: [cartLine(quantity: 3)]);
    final first = controller.setLineQuantity(cartLine(), 3);
    stub
      ..gate = null
      ..snapshot = cartSnapshot(
        lines: [cartLine(quantity: 3), cartLine(id: 2, variantId: 102)],
      );
    await controller.setLineQuantity(cartLine(id: 2, variantId: 102), 2);
    expect(c.read(cartProvider).snapshot.lines, hasLength(2));

    // The first answer arrives late, with the older cart: ignored.
    stub.snapshot = cartSnapshot(lines: [cartLine(quantity: 3)]);
    held.complete();
    await first;
    expect(c.read(cartProvider).snapshot.lines, hasLength(2));
  });

  test('the fix action reduces to what is available, or removes', () async {
    final stub = StubCartRepository(cartSnapshot());
    final c = containerWith(stub);
    final controller = c.read(cartProvider.notifier);
    await controller.fixLine(
      cartLine(quantity: 4, issue: CartLineIssue.reduced, available: 2),
    );
    await controller.fixLine(
      cartLine(variantId: 102, issue: CartLineIssue.unavailable),
    );
    await controller.fixLine(cartLine(variantId: 103));
    expect(writes(stub), ['set:101:2', 'set:102:0']);
  });

  test('a line can go down past its cap but not up', () async {
    final stub = StubCartRepository(cartSnapshot());
    final c = containerWith(stub);
    final controller = c.read(cartProvider.notifier);
    final over = cartLine(quantity: 4, orderable: 2);
    await expectLater(
      controller.setLineQuantity(over, 5),
      throwsA(isA<CartLimitException>()),
    );
    await controller.setLineQuantity(over, 3);
    expect(writes(stub), ['set:101:3']);
  });

  test('coupon, tip and instructions go to the server', () async {
    final stub = StubCartRepository(cartSnapshot());
    final c = containerWith(stub);
    final controller = c.read(cartProvider.notifier);
    await controller.applyCoupon('JIVO50');
    await controller.removeCoupon();
    await controller.setTip('20.00');
    await controller.setInstructions(
      const DeliveryInstructions(tags: {InstructionTag.leaveAtDoor}),
    );
    expect(writes(stub), [
      'coupon:JIVO50',
      'coupon:remove',
      'update',
      'update',
    ]);
    expect(stub.updates.first.tip, '20.00');
    expect(stub.updates.last.instructions!.tags, {InstructionTag.leaveAtDoor});
    expect(c.read(cartProvider).updating, isFalse);
  });

  test('a coupon error reaches the caller and clears updating', () async {
    await cart().increment(variant());
    await expectLater(
      cart().applyCoupon('NOPE'),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.couponInvalid,
        ),
      ),
    );
    expect(state().updating, isFalse);
  });
}
