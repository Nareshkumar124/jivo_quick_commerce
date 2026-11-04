import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:customer_app/features/orders/presentation/order_history_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

/// The order-history controllers on the fake server.
void main() {
  late FakeCommerceBackend backend;
  late FakeUrlOpener urls;
  late ProviderContainer container;

  setUp(() {
    backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
    urls = FakeUrlOpener();
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        cartAvailableProvider.overrideWithValue(true),
        orderHistoryRepositoryProvider.overrideWithValue(backend),
        orderRepositoryProvider.overrideWithValue(backend),
        cartRepositoryProvider.overrideWithValue(backend),
        urlOpenerProvider.overrideWithValue(urls),
      ],
    );
    addTearDown(container.dispose);
  });

  int idOf(OrderStatus status) =>
      backend.orders.firstWhere((o) => o.status == status).id;

  test('the list loads, splits active/past and pages', () async {
    backend.historyPageSize = 2;
    final sub = container.listen(orderListProvider, (_, _) {});
    addTearDown(sub.close);
    final first = await container.read(orderListProvider.future);
    expect(first.items, hasLength(2));
    expect(first.active.single.status, OrderStatus.packing);
    expect(first.past.single.status, OrderStatus.cancelled);
    expect(first.hasMore, isTrue);

    await container.read(orderListProvider.notifier).loadMore();
    final all = container.read(orderListProvider).value!;
    expect(all.items, hasLength(3));
    expect(all.hasMore, isFalse);
    // Nothing more to load: a no-op.
    await container.read(orderListProvider.notifier).loadMore();
    expect(container.read(orderListProvider).value!.items, hasLength(3));
  });

  test('a failed next page keeps the rows and the error', () async {
    backend.historyPageSize = 2;
    final sub = container.listen(orderListProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(orderListProvider.future);
    backend.failNext = const ApiError(code: ApiErrorCode.network);
    await container.read(orderListProvider.notifier).loadMore();
    final state = container.read(orderListProvider).value!;
    expect(state.items, hasLength(2));
    expect(state.loadMoreError, isA<ApiError>());
    expect(state.loadingMore, isFalse);

    await container.read(orderListProvider.notifier).refresh();
    expect(container.read(orderListProvider).value!.loadMoreError, isNull);
  });

  test('cancel replaces the detail and resets the busy state', () async {
    final id = idOf(OrderStatus.packing);
    // Make it cancellable: a fresh COD order.
    backend.advanceOrder(id, OrderStatus.accepted);
    final sub = container.listen(orderDetailProvider(id), (_, _) {});
    addTearDown(sub.close);
    final actions = container.listen(orderActionsProvider(id), (_, _) {});
    addTearDown(actions.close);
    await container.read(orderDetailProvider(id).future);

    final future = container
        .read(orderActionsProvider(id).notifier)
        .cancel(CancelReason.orderedByMistake);
    expect(container.read(orderActionsProvider(id)), OrderAction.cancel);
    // A second action while one runs is ignored.
    expect(
      await container.read(orderActionsProvider(id).notifier).reorder(),
      isNull,
    );
    final cancelled = await future;
    expect(cancelled!.status, OrderStatus.cancelled);
    expect(container.read(orderActionsProvider(id)), isNull);
    expect(
      container.read(orderDetailProvider(id)).value!.status,
      OrderStatus.cancelled,
    );
  });

  test('a failed cancel is rethrown and frees the button', () async {
    final id = idOf(OrderStatus.packing);
    final actions = container.listen(orderActionsProvider(id), (_, _) {});
    addTearDown(actions.close);
    await expectLater(
      container
          .read(orderActionsProvider(id).notifier)
          .cancel(CancelReason.other),
      throwsA(isA<ApiError>()),
    );
    expect(container.read(orderActionsProvider(id)), isNull);
  });

  test('reorder fills the server cart and refreshes the cart state', () async {
    final id = idOf(OrderStatus.delivered);
    final cart = container.listen(cartProvider, (_, _) {});
    addTearDown(cart.close);
    final actions = container.listen(orderActionsProvider(id), (_, _) {});
    addTearDown(actions.close);

    final result = await container
        .read(orderActionsProvider(id).notifier)
        .reorder();
    // The demo groundnut oil is out of stock now.
    expect(result!.unavailable.single.reason, ReorderSkipReason.outOfStock);
    expect(container.read(cartProvider).snapshot.quantityOf(101), 2);
  });

  test('the invoice opens in another app', () async {
    final id = idOf(OrderStatus.delivered);
    final actions = container.listen(orderActionsProvider(id), (_, _) {});
    addTearDown(actions.close);
    final notifier = container.read(orderActionsProvider(id).notifier);
    expect(await notifier.openInvoice(), isTrue);
    expect(urls.opened.single.path, endsWith('.pdf'));

    urls.result = false;
    expect(await notifier.openInvoice(), isFalse);
  });
}
