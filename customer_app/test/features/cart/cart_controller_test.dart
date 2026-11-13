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

/// The fake server, recording every quantity sent to `POST /cart/items/`.
class _RecordingCommerce extends FakeCommerceBackend {
  _RecordingCommerce() : super(latency: Duration.zero);

  final sent = <int>[];

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) {
    sent.add(quantity);
    return super.setQuantity(variantId, quantity, preview: preview);
  }
}

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

  test("the fix sets the server's orderable_quantity (0 removes)", () async {
    final stub = StubCartRepository(cartSnapshot());
    final c = containerWith(stub);
    final controller = c.read(cartProvider.notifier);
    await controller.fixLine(
      cartLine(
        quantity: 4,
        orderable: 2,
        issue: CartIssueCode.quantityUnavailable,
      ),
    );
    await controller.fixLine(
      cartLine(variantId: 102, orderable: 0, issue: CartIssueCode.outOfStock),
    );
    await controller.fixLine(cartLine(variantId: 103)); // no issue: nothing
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

  group('minimum per order', () {
    CatalogVariant water({int orderable = 20}) =>
        variant(id: 1501, orderable: orderable, maxQty: 1000, minQty: 5);

    test('ADD sets the minimum in one request; plus adds one', () async {
      final stub = StubCartRepository(cartSnapshot());
      final c = containerWith(stub);
      final controller = c.read(cartProvider.notifier);
      await controller.increment(water());
      expect(writes(stub), ['set:1501:5']);

      stub.snapshot = cartSnapshot(
        lines: [cartLine(variantId: 1501, quantity: 5, minQty: 5)],
      );
      await controller.refresh();
      await controller.increment(water());
      expect(writes(stub).last, 'set:1501:6');
    });

    test('minus at the minimum removes the line; above it, one', () async {
      final stub = StubCartRepository(
        cartSnapshot(
          lines: [cartLine(variantId: 1501, quantity: 6, minQty: 5)],
        ),
      );
      final c = containerWith(stub);
      final controller = c.read(cartProvider.notifier);
      await controller.refresh();
      await controller.decrement(water());
      expect(writes(stub), ['set:1501:5']);

      stub.snapshot = cartSnapshot(
        lines: [cartLine(variantId: 1501, quantity: 5, minQty: 5)],
      );
      await controller.refresh();
      await controller.decrement(water());
      expect(writes(stub).last, 'set:1501:0');
    });

    test('min 1 behaves as before: ADD 1, minus at 1 removes', () async {
      await cart().increment(variant(), productName: 'Jivo Canola Oil');
      expect(state().quantityOf(101), 1);
      await cart().decrement(variant());
      expect(state().snapshot.isEmpty, isTrue);
    });

    test('fewer orderable than the minimum is out of stock', () async {
      final scarce = water(orderable: 4);
      expect(scarce.inStock, isFalse);
      expect(scarce.maxSelectable, 0);
      expect(water(orderable: 5).inStock, isTrue);
      await expectLater(
        cart().increment(scarce),
        throwsA(isA<CartLimitException>()),
      );
      expect(state().quantityOf(1501), 0);
    });

    test('a cart line never steps into 1..min-1', () async {
      final stub = StubCartRepository(cartSnapshot());
      final c = containerWith(stub);
      final controller = c.read(cartProvider.notifier);
      final atMin = cartLine(
        variantId: 1501,
        quantity: 5,
        orderable: 20,
        minQty: 5,
      );
      await controller.setLineQuantity(atMin, 4); // minus: removes
      await controller.setLineQuantity(atMin, 6); // plus: one more
      // A line below the minimum (raised after adding): plus goes to min.
      await controller.setLineQuantity(
        cartLine(variantId: 1502, quantity: 2, orderable: 20, minQty: 5),
        3,
      );
      expect(writes(stub), ['set:1501:0', 'set:1501:6', 'set:1502:5']);
    });

    test('the MIN_QTY_REQUIRED fix raises the line to the minimum', () async {
      final stub = StubCartRepository(cartSnapshot());
      final c = containerWith(stub);
      await c
          .read(cartProvider.notifier)
          .fixLine(
            cartLine(
              variantId: 1501,
              quantity: 2,
              orderable: 20,
              minQty: 5,
              issue: CartIssueCode.minQtyRequired,
            ),
          );
      expect(writes(stub), ['set:1501:5']);
    });

    test(
      'a line already below the minimum: up goes to it, down removes',
      () async {
        final below = cartLine(
          variantId: 1501,
          quantity: 3,
          orderable: 20,
          minQty: 5,
        );
        final stub = StubCartRepository(cartSnapshot(lines: [below]));
        final c = containerWith(stub);
        final controller = c.read(cartProvider.notifier);
        await controller.refresh();
        await controller.increment(water()); // tile +
        await controller.decrement(water()); // tile −
        await controller.setLineQuantity(below, 4); // cart line +
        await controller.setLineQuantity(below, 2); // cart line −
        expect(writes(stub), [
          'set:1501:5',
          'set:1501:0',
          'set:1501:5',
          'set:1501:0',
        ]);
      },
    );

    test('a failed ADD sends the minimum once; nothing in 1..min-1 is ever '
        'sent', () async {
      final backend = _RecordingCommerce();
      final c = containerWith(backend);
      final controller = c.read(cartProvider.notifier);
      backend.failNext = const ApiError(code: ApiErrorCode.network);
      await expectLater(
        controller.increment(water()),
        throwsA(isA<ApiError>()),
      );
      expect(backend.sent, [5]);
      expect(c.read(cartProvider).quantityOf(1501), 0);

      await controller.increment(water()); // ADD
      await controller.increment(water()); // +
      await controller.decrement(water()); // −
      await controller.decrement(water()); // − at the minimum
      expect(backend.sent, [5, 5, 6, 5, 0]);
      expect(backend.sent.where((q) => q > 0 && q < 5), isEmpty);
    });

    test('a minimum the server reports is used on the next tap', () async {
      // The tile still says min 1; the server raised it to 5.
      final stale = variant(id: 1501, orderable: 20, maxQty: 1000);
      repository.minimums[1501] = 5;
      await expectLater(
        cart().increment(stale),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.minQtyRequired)
              .having((e) => e.minQtyPerOrder, 'min', 5),
        ),
      );
      expect(state().quantityOf(1501), 0);

      await cart().increment(stale);
      expect(state().quantityOf(1501), 5);
      await cart().decrement(stale);
      expect(state().quantityOf(1501), 0);
    });

    group('a learned minimum gives way to the server', () {
      late _RecordingCommerce backend;
      late CartController controller;
      // The tile's catalog predates the raise: it still shows min 1.
      final stale = variant(id: 1501, orderable: 20, maxQty: 1000);

      Matcher minError() => throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.minQtyRequired,
        ),
      );

      setUp(() async {
        backend = _RecordingCommerce()..minimums[1501] = 5;
        final c = containerWith(backend);
        controller = c.read(cartProvider.notifier);
        await controller.refresh(); // the first load, done
        await expectLater(controller.increment(stale), minError()); // learns 5
        backend.minimums.remove(1501); // then the server lowers it to 1
      });

      test(
        'refresh forgets it: learned 5, the server says 1, ADD sends 1',
        () async {
          await controller.refresh();
          await controller.increment(stale);
          expect(backend.sent, [1, 1]);
        },
      );

      test("a cart answer's minimum replaces it", () async {
        await controller.increment(stale); // still the learned 5
        await controller.decrement(stale); // the cart now says min 1
        final line = controller.state.snapshot.lineFor(1501)!;
        await controller.removeLine(line);
        await controller.increment(stale); // nothing learned is left
        expect(backend.sent, [1, 5, 4, 0, 1]);
      });

      test('a catalog variant that shows the minimum replaces it', () async {
        backend.failNext = const ApiError(code: ApiErrorCode.network);
        await expectLater(
          controller.increment(variant(id: 1501, orderable: 20, minQty: 5)),
          throwsA(isA<ApiError>()),
        );
        // The catalog reloads with the server's new minimum, 1.
        await controller.increment(stale);
        expect(backend.sent, [1, 5, 1]);
      });
    });
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
