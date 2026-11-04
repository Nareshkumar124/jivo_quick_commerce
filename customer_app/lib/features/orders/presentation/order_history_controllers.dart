import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../../cart/presentation/cart_controller.dart';
import '../domain/order.dart';
import '../domain/order_history.dart';
import 'order_providers.dart';
import 'pending_payment.dart';

/// The loaded pages of "My orders".
@immutable
class OrderListState {
  const OrderListState({
    this.items = const [],
    this.nextPage,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<OrderListItem> items;
  final int? nextPage;
  final bool loadingMore;

  /// Why the last next-page load failed (a footer retry).
  final Object? loadMoreError;

  bool get hasMore => nextPage != null;

  /// The server lists active orders first (`03 §2.10`).
  List<OrderListItem> get active => [
    for (final order in items)
      if (order.isActive) order,
  ];

  List<OrderListItem> get past => [
    for (final order in items)
      if (!order.isActive) order,
  ];

  OrderListState copyWith({
    List<OrderListItem>? items,
    int? nextPage,
    bool clearNextPage = false,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearError = false,
  }) => OrderListState(
    items: items ?? this.items,
    nextPage: clearNextPage ? null : (nextPage ?? this.nextPage),
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
  );
}

/// "My orders" with infinite scroll (`03 §2.10`).
class OrderListController extends AsyncNotifier<OrderListState> {
  @override
  Future<OrderListState> build() async {
    final first = await ref.read(orderHistoryRepositoryProvider).listOrders();
    return OrderListState(items: first.items, nextPage: first.nextPage);
  }

  /// Loads the next page, one at a time. A failure stays in
  /// [OrderListState.loadMoreError].
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, clearError: true));
    try {
      final page = await ref
          .read(orderHistoryRepositoryProvider)
          .listOrders(page: current.nextPage!);
      if (!ref.mounted) return;
      // A row may move to an earlier page between requests; keep one copy.
      final seen = {for (final order in current.items) order.id};
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            for (final order in page.items)
              if (!seen.contains(order.id)) order,
          ],
          nextPage: page.nextPage,
          clearNextPage: page.nextPage == null,
          loadingMore: false,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: error),
      );
    }
  }

  /// Pull to refresh: reloads from page 1.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final orderListProvider =
    AsyncNotifierProvider.autoDispose<OrderListController, OrderListState>(
      OrderListController.new,
    );

/// One order's detail (`GET /orders/{id}/`).
class OrderDetailController extends AsyncNotifier<OrderDetail> {
  OrderDetailController(this.orderId);

  final int orderId;

  @override
  Future<OrderDetail> build() =>
      ref.read(orderHistoryRepositoryProvider).getOrderDetail(orderId);

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }

  /// The server's newer copy of the order (e.g. the cancel response).
  void replace(OrderDetail order) => state = AsyncData(order);

  /// Re-fetches in the background, keeping the shown order (no skeleton);
  /// used when live tracking reports a new status. A failure keeps the
  /// current copy.
  Future<void> refreshQuietly() async {
    try {
      final order = await ref
          .read(orderHistoryRepositoryProvider)
          .getOrderDetail(orderId);
      if (ref.mounted) state = AsyncData(order);
    } catch (_) {
      // The next status change or pull to refresh tries again.
    }
  }
}

final orderDetailProvider = AsyncNotifierProvider.autoDispose
    .family<OrderDetailController, OrderDetail, int>(OrderDetailController.new);

/// What an order-detail button is doing.
enum OrderAction { cancel, reorder, invoice }

/// Cancel, reorder and invoice for one order. One action runs at a time;
/// [state] is the running one (its button shows progress, `03 §4`).
/// Failures are rethrown as they came (`ApiError`), for the screen to
/// show through jivo_core's messages.
class OrderActionsController extends Notifier<OrderAction?> {
  OrderActionsController(this.orderId);

  final int orderId;

  @override
  OrderAction? build() => null;

  Future<T?> _run<T>(OrderAction action, Future<T> Function() call) async {
    if (state != null) return null;
    state = action;
    try {
      return await call();
    } finally {
      if (ref.mounted) state = null;
    }
  }

  /// `POST /orders/{id}/cancel/` (`08 §7`). The detail shows the server's
  /// cancelled order; the list and the pending-payment banner reload.
  Future<OrderDetail?> cancel(CancelReason reason) =>
      _run(OrderAction.cancel, () async {
        final order = await ref
            .read(orderHistoryRepositoryProvider)
            .cancel(orderId, reason);
        if (ref.mounted) {
          ref.read(orderDetailProvider(orderId).notifier).replace(order);
          ref.invalidate(orderListProvider);
          ref.invalidate(orderProvider(orderId));
          ref.read(pendingPaymentProvider.notifier).check();
        }
        return order;
      });

  /// `POST /orders/{id}/reorder/`; then the cart shows the server's cart.
  Future<ReorderResult?> reorder() => _run(OrderAction.reorder, () async {
    final result = await ref
        .read(orderHistoryRepositoryProvider)
        .reorder(orderId);
    if (ref.mounted) await ref.read(cartProvider.notifier).refresh();
    return result;
  });

  /// Fetches the invoice link and opens the PDF outside the app. False
  /// when no app could open it.
  ///
  /// Only an `https` link with a host is opened; anything else (or a link
  /// that doesn't parse) is reported as false, never launched.
  Future<bool?> openInvoice() => _run(OrderAction.invoice, () async {
    final InvoiceLink link;
    try {
      link = await ref.read(orderHistoryRepositoryProvider).invoice(orderId);
    } on FormatException {
      return false;
    }
    if (!isSafeInvoiceUrl(link.url)) return false;
    return ref.read(urlOpenerProvider).open(link.url);
  });
}

/// The invoice link may be opened: `https` with a host.
bool isSafeInvoiceUrl(Uri url) => url.scheme == 'https' && url.host.isNotEmpty;

final orderActionsProvider = NotifierProvider.autoDispose
    .family<OrderActionsController, OrderAction?, int>(
      OrderActionsController.new,
    );
