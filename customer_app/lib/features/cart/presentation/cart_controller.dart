import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/cart.dart';

/// What the stepper can't do; the widget turns it into a message.
enum CartLimit { maxReached }

class CartLimitException implements Exception {
  const CartLimitException(this.limit, this.max);

  final CartLimit limit;

  /// The cap that was hit.
  final int max;
}

@immutable
class CartState {
  const CartState({
    this.snapshot = CartSnapshot.empty,
    this.pending = const {},
  });

  final CartSnapshot snapshot;

  /// Variants with a change in flight; their steppers are disabled.
  final Set<int> pending;

  int quantityOf(int variantId) => snapshot.quantityOf(variantId);

  /// Units of [product] in the cart, over all its variants.
  int quantityOfProduct(CatalogProduct product) =>
      product.variants.fold(0, (sum, v) => sum + quantityOf(v.id));

  bool isPending(int variantId) => pending.contains(variantId);

  CartState copyWith({CartSnapshot? snapshot, Set<int>? pending}) => CartState(
    snapshot: snapshot ?? this.snapshot,
    pending: pending ?? this.pending,
  );
}

/// The ADD/stepper state behind [CartRepository] (`03 §2.5`, `§2.6`).
///
/// Quantities are capped at the server's `orderable_quantity`
/// (`min(stock, max_qty_per_order)`); the server still validates every
/// change. One change per variant is in flight at a time.
class CartController extends Notifier<CartState> {
  @override
  CartState build() {
    Future.microtask(_load);
    return const CartState();
  }

  Future<void> _load() async {
    try {
      final snapshot = await ref.read(cartRepositoryProvider).load();
      if (ref.mounted) state = state.copyWith(snapshot: snapshot);
    } catch (_) {
      // An empty cart until the first change; the next change reloads it.
    }
  }

  /// Adds one. Throws [CartLimitException] at the cap, or the repository's
  /// `ApiError`.
  Future<void> increment(CatalogVariant variant) async {
    final next = state.quantityOf(variant.id) + 1;
    if (next > variant.maxSelectable) {
      throw CartLimitException(CartLimit.maxReached, variant.maxSelectable);
    }
    await _set(variant.id, next);
  }

  /// Removes one.
  Future<void> decrement(CatalogVariant variant) async {
    final current = state.quantityOf(variant.id);
    if (current == 0) return;
    await _set(variant.id, current - 1);
  }

  /// Empties the cart (store change).
  Future<void> clear() async {
    final snapshot = await ref.read(cartRepositoryProvider).clear();
    if (ref.mounted) state = CartState(snapshot: snapshot);
  }

  Future<void> _set(int variantId, int quantity) async {
    if (state.isPending(variantId)) return;
    state = state.copyWith(pending: {...state.pending, variantId});
    try {
      final snapshot = await ref
          .read(cartRepositoryProvider)
          .setQuantity(variantId, quantity);
      if (ref.mounted) state = state.copyWith(snapshot: snapshot);
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
