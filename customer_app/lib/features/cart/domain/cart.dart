import 'package:flutter/foundation.dart';

/// What the cart holds, as the server reports it.
///
/// Money ([itemTotal]) is never computed in the app (`08 §6`): it is shown
/// only when the server sends it. The Phase 2 in-memory cart has no server,
/// so it is null until the Phase 3 cart API.
@immutable
class CartSnapshot {
  const CartSnapshot({
    this.quantities = const {},
    this.itemCount = 0,
    this.itemTotal,
  });

  static const empty = CartSnapshot();

  /// Quantity per variant id.
  final Map<int, int> quantities;

  /// Units in the cart, as the server counts them.
  final int itemCount;

  /// Decimal string from the server, or null when not known.
  final String? itemTotal;

  bool get isEmpty => itemCount == 0;

  int quantityOf(int variantId) => quantities[variantId] ?? 0;
}
