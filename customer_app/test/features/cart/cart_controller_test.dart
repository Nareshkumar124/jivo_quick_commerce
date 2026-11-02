import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../catalog/catalog_fixtures.dart';

void main() {
  late InMemoryCartRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = InMemoryCartRepository();
    container = ProviderContainer(
      overrides: [cartRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  CartController cart() => container.read(cartProvider.notifier);

  test('increment and decrement go through the repository', () async {
    final oil = variant();
    await cart().increment(oil);
    await cart().increment(oil);
    expect(container.read(cartProvider).quantityOf(101), 2);
    expect(container.read(cartProvider).snapshot.itemCount, 2);

    await cart().decrement(oil);
    await cart().decrement(oil);
    await cart().decrement(oil); // already 0: no call
    expect(container.read(cartProvider).snapshot.isEmpty, isTrue);
    expect((await repository.load()).isEmpty, isTrue);
  });

  test('caps at the server\'s orderable_quantity', () async {
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
    expect(container.read(cartProvider).quantityOf(101), 1);
  });

  test('never computes money: the in-memory cart has no total', () async {
    await cart().increment(variant());
    expect(container.read(cartProvider).snapshot.itemTotal, isNull);
  });

  test('clear empties the cart', () async {
    await cart().increment(variant());
    await cart().increment(variant(id: 7));
    await cart().clear();
    expect(container.read(cartProvider).snapshot.isEmpty, isTrue);
  });

  test('a failed change keeps the old quantity and clears pending', () async {
    repository.failNext = Exception('boom');
    await expectLater(cart().increment(variant()), throwsException);
    final state = container.read(cartProvider);
    expect(state.quantityOf(101), 0);
    expect(state.isPending(101), isFalse);
  });
}
