import 'package:jivo_core/jivo_core.dart';

import '../domain/cart.dart';

/// The customer's cart for the selected store (`03 §2.8`, `06 §2.5`).
/// Implementations throw `ApiError` (e.g. `STOCK_UNAVAILABLE`,
/// `MAX_QTY_EXCEEDED`).
abstract interface class CartRepository {
  Future<CartSnapshot> load();

  /// Sets [variantId] to [quantity]; 0 removes the line.
  Future<CartSnapshot> setQuantity(int variantId, int quantity);

  /// Empties the cart (e.g. when the store changes, `03 §2.3`).
  Future<CartSnapshot> clear();
}

/// TODO(api): the server cart arrives in Phase 3. Until then quantities live
/// in memory for this app session. It never computes money, so
/// [CartSnapshot.itemTotal] stays null.
class InMemoryCartRepository implements CartRepository {
  final Map<int, int> _quantities = {};

  /// When set, the next [setQuantity] throws it once (tests).
  Object? failNext;

  CartSnapshot get _snapshot => CartSnapshot(
    quantities: Map.unmodifiable(_quantities),
    itemCount: _quantities.values.fold(0, (sum, qty) => sum + qty),
  );

  @override
  Future<CartSnapshot> load() async => _snapshot;

  @override
  Future<CartSnapshot> setQuantity(int variantId, int quantity) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    if (quantity <= 0) {
      _quantities.remove(variantId);
    } else {
      _quantities[variantId] = quantity;
    }
    return _snapshot;
  }

  @override
  Future<CartSnapshot> clear() async {
    _quantities.clear();
    return _snapshot;
  }
}

/// Staging and prod before Phase 3: there is no cart yet. The UI checks
/// `cartAvailableProvider` and never calls this.
class UnavailableCartRepository implements CartRepository {
  const UnavailableCartRepository();

  @override
  Future<CartSnapshot> load() async => CartSnapshot.empty;

  @override
  Future<CartSnapshot> setQuantity(int variantId, int quantity) =>
      throw const ApiError(code: ApiErrorCode.serviceUnavailable);

  @override
  Future<CartSnapshot> clear() async => CartSnapshot.empty;
}
