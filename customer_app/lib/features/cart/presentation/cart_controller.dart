import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/cart_repository.dart';
import '../domain/cart.dart';

/// What the stepper can't do; the widget turns it into a message.
enum CartLimit { maxReached }

class CartLimitException implements Exception {
  const CartLimitException(this.limit, this.max);

  final CartLimit limit;

  /// The cap that was hit.
  final int max;
}

/// Loading the cart for the cart screen.
enum CartLoad { idle, loading, ready, failed }

@immutable
class CartState {
  const CartState({
    this.snapshot = CartSnapshot.empty,
    this.pending = const {},
    this.load = CartLoad.idle,
    this.loadError,
    this.updating = false,
  });

  final CartSnapshot snapshot;

  /// Variants with a change in flight; their steppers are disabled.
  final Set<int> pending;

  final CartLoad load;

  /// Why the last load failed (the cart screen's error state).
  final Object? loadError;

  /// A coupon, tip or instructions change is in flight.
  final bool updating;

  /// The bill on screen may be about to change: checkout waits.
  bool get busy => updating || pending.isNotEmpty || load == CartLoad.loading;

  int quantityOf(int variantId) => snapshot.quantityOf(variantId);

  /// Units of [product] in the cart, over all its variants.
  int quantityOfProduct(CatalogProduct product) =>
      product.variants.fold(0, (sum, v) => sum + quantityOf(v.id));

  bool isPending(int variantId) => pending.contains(variantId);

  CartState copyWith({
    CartSnapshot? snapshot,
    Set<int>? pending,
    CartLoad? load,
    Object? loadError,
    bool clearLoadError = false,
    bool? updating,
  }) => CartState(
    snapshot: snapshot ?? this.snapshot,
    pending: pending ?? this.pending,
    load: load ?? this.load,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    updating: updating ?? this.updating,
  );
}

/// The server cart behind the ADD stepper, the cart bar and the cart
/// screen (`03 §2.5`, `§2.8`).
///
/// Every change goes to [CartRepository], and the cart it returns (lines,
/// stock flags, bill) replaces the state: nothing is recalculated here.
/// Quantities are capped at the server's `orderable_quantity`; the server
/// still validates every change. One change per variant is in flight at a
/// time, and a slower, older response never overwrites a newer one.
class CartController extends Notifier<CartState> {
  int _issued = 0;
  int _applied = 0;
  int _latestLoad = 0;
  int? _addressId;

  @override
  CartState build() {
    Future.microtask(refresh);
    return const CartState();
  }

  CartRepository get _repository => ref.read(cartRepositoryProvider);

  /// Applies [snapshot] unless a newer request's answer already arrived.
  void _apply(int ticket, CartSnapshot snapshot) {
    if (!ref.mounted || ticket < _applied) return;
    _applied = ticket;
    state = state.copyWith(snapshot: snapshot);
  }

  /// Reloads the cart: on opening the cart screen and before checkout
  /// (stock re-validation, `03 §2.8`). [addressId] (kept for later loads)
  /// prices the bill for that address. Never throws: a failure is kept in
  /// [CartState.loadError].
  Future<void> refresh({int? addressId}) async {
    if (addressId != null) _addressId = addressId;
    if (!ref.mounted) return;
    final ticket = ++_issued;
    _latestLoad = ticket;
    state = state.copyWith(load: CartLoad.loading, clearLoadError: true);
    try {
      final snapshot = await _repository.load(addressId: _addressId);
      _apply(ticket, snapshot);
      if (ref.mounted && ticket == _latestLoad) {
        state = state.copyWith(load: CartLoad.ready, clearLoadError: true);
      }
    } catch (error) {
      // Only the latest load decides the loading/error state.
      if (ref.mounted && ticket == _latestLoad) {
        state = state.copyWith(load: CartLoad.failed, loadError: error);
      }
    }
  }

  /// Adds one of [variant]. Throws [CartLimitException] at the cap, or the
  /// repository's `ApiError`. [productName] only feeds the dev fake cart.
  Future<void> increment(CatalogVariant variant, {String? productName}) async {
    final next = state.quantityOf(variant.id) + 1;
    if (next > variant.maxSelectable) {
      throw CartLimitException(CartLimit.maxReached, variant.maxSelectable);
    }
    await _set(
      variant.id,
      next,
      preview: CartLinePreview.of(variant, productName ?? variant.name),
    );
  }

  /// Removes one of [variant].
  Future<void> decrement(CatalogVariant variant) async {
    final current = state.quantityOf(variant.id);
    if (current == 0) return;
    await _set(variant.id, current - 1);
  }

  /// Sets a cart line's quantity from the cart screen, capped at the
  /// line's `orderable_quantity`.
  Future<void> setLineQuantity(CartLine line, int quantity) async {
    if (quantity > line.quantity && quantity > line.orderableQuantity) {
      throw CartLimitException(CartLimit.maxReached, line.orderableQuantity);
    }
    await _set(line.variantId, quantity < 0 ? 0 : quantity);
  }

  Future<void> removeLine(CartLine line) => _set(line.variantId, 0);

  /// The "fix" action on a flagged line: down to what is available, or
  /// out of the cart when nothing is.
  Future<void> fixLine(CartLine line) => switch (line.issue) {
    CartLineIssue.reduced => _set(line.variantId, line.availableQuantity ?? 0),
    CartLineIssue.unavailable => _set(line.variantId, 0),
    CartLineIssue.none => Future.value(),
  };

  /// Empties the cart (store change).
  Future<void> clear() async {
    final ticket = ++_issued;
    final snapshot = await _repository.clear();
    _apply(ticket, snapshot);
  }

  /// Throws the server's `COUPON_*` error for the coupon sheet to show.
  Future<void> applyCoupon(String code) =>
      _update((repository) => repository.applyCoupon(code));

  Future<void> removeCoupon() =>
      _update((repository) => repository.removeCoupon());

  /// [tip] is a decimal string; `"0.00"` removes it.
  Future<void> setTip(String tip) =>
      _update((repository) => repository.update(CartUpdate(tip: tip)));

  Future<void> setInstructions(DeliveryInstructions instructions) => _update(
    (repository) => repository.update(CartUpdate(instructions: instructions)),
  );

  Future<void> _update(
    Future<CartSnapshot> Function(CartRepository repository) call,
  ) async {
    final ticket = ++_issued;
    state = state.copyWith(updating: true);
    try {
      _apply(ticket, await call(_repository));
    } finally {
      if (ref.mounted) state = state.copyWith(updating: false);
    }
  }

  Future<void> _set(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) async {
    if (state.isPending(variantId)) return;
    final ticket = ++_issued;
    state = state.copyWith(pending: {...state.pending, variantId});
    try {
      _apply(
        ticket,
        await _repository.setQuantity(variantId, quantity, preview: preview),
      );
    } finally {
      if (ref.mounted) {
        state = state.copyWith(pending: {...state.pending}..remove(variantId));
      }
    }
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
