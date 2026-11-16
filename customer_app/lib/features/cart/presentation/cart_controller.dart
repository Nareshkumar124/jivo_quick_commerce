import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/repositories.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../location/presentation/delivery_controller.dart';
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

/// The server cart behind ADD and the quantity box, the cart bar and the cart
/// screen (`03 §2.5`, `§2.8`).
///
/// Every change goes to [CartRepository], and the cart it returns (lines,
/// stock flags, bill) replaces the state: nothing is recalculated here.
/// Quantities are capped at the server's `orderable_quantity` and never
/// set between 1 and `min_qty_per_order - 1` (the server refuses those);
/// the server still validates every change. One change per variant is in
/// flight at a time, and a slower, older response never overwrites a newer
/// one.
class CartController extends Notifier<CartState> {
  int _issued = 0;
  int _applied = 0;
  int _latestLoad = 0;
  int? _addressId;

  /// Minimums the server reported with `MIN_QTY_REQUIRED`, by variant id:
  /// the catalog a tile came from may predate a raised minimum, so the next
  /// tap uses the server's. Short-lived: cleared on [refresh] (which a
  /// store change runs too) and dropped as soon as the server's own copy of
  /// the variant arrives, in a cart answer or as a catalog variant that
  /// already shows that minimum. The server's value always wins.
  final _serverMin = <int, int>{};

  /// The minimum per order for [variant]: the cart's copy of it (the
  /// server's latest answer) when it is in the cart; else a minimum the
  /// server reported while [variant] still shows a lower one; else the
  /// variant's own.
  int _minFor(CatalogVariant variant) {
    final line = state.snapshot.lineFor(variant.id);
    if (line != null) return line.minQty;
    final reported = _serverMin[variant.id];
    if (reported == null) return variant.minQty;
    if (variant.minQty >= reported) {
      // The catalog caught up: its own value is used from now on.
      _serverMin.remove(variant.id);
      return variant.minQty;
    }
    return reported;
  }

  /// Remembers the minimum in a `MIN_QTY_REQUIRED` answer for [variantId].
  void _learnMin(int variantId, Object error) {
    final apiError = ApiError.from(error);
    if (apiError.code != ApiErrorCode.minQtyRequired) return;
    final minimum = apiError.minQtyPerOrder;
    if (minimum != null && minimum > 1) _serverMin[variantId] = minimum;
  }

  @override
  CartState build() {
    // The store-change reload is [cartStoreSyncProvider]'s job: the cart
    // must not depend on the delivery state, which reads the cart.
    Future.microtask(refresh);
    return const CartState();
  }

  /// The server says the store is gone: re-check the location, as catalog
  /// calls do (`storeScoped`). A missing store on this side (no location
  /// yet) is not reported: the store-scope listener reloads once it's known.
  void _checkStore(Object error) {
    final apiError = ApiError.from(error);
    if (apiError.code == ApiErrorCode.storeNotFound &&
        apiError.rawCode != null) {
      Future.microtask(ref.read(deliveryProvider.notifier).storeGone);
    }
  }

  CartRepository get _repository => ref.read(cartRepositoryProvider);

  /// Applies [snapshot] unless a newer request's answer already arrived.
  void _apply(int ticket, CartSnapshot snapshot) {
    if (!ref.mounted || ticket < _applied) return;
    _applied = ticket;
    // These lines carry the server's own minimum: it replaces a learned one.
    for (final line in snapshot.lines) {
      _serverMin.remove(line.variantId);
    }
    state = state.copyWith(snapshot: snapshot);
  }

  /// Reloads the cart: on opening the cart screen and before checkout
  /// (stock re-validation, `03 §2.8`). [addressId] (kept for later loads)
  /// prices the bill for that address. Never throws: a failure is kept in
  /// [CartState.loadError]. Forgets every learned minimum (the store may
  /// have changed; the server's values come back with the cart and the
  /// catalog).
  Future<void> refresh({int? addressId}) async {
    if (addressId != null) _addressId = addressId;
    _serverMin.clear();
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
      _checkStore(error);
      // Only the latest load decides the loading/error state.
      if (ref.mounted && ticket == _latestLoad) {
        state = state.copyWith(load: CartLoad.failed, loadError: error);
      }
    }
  }

  /// [refresh] for the delivery location's saved address [addressId], or
  /// for none (a pin, the current location, or a deleted address). Unlike
  /// [refresh], null forgets the remembered address instead of keeping it.
  Future<void> refreshForAddress(int? addressId) {
    _addressId = addressId;
    return refresh();
  }

  /// A change's answer is checked against no address (only `GET /cart/`
  /// takes `?address_id=`), so with a saved address chosen it wrongly says
  /// ADDRESS_REQUIRED until [_reloadForAddress] brings the real answer. Drop
  /// just that blocker meanwhile, so the red warning doesn't flash after
  /// every change. Proceed still re-checks the cart for the address first.
  CartSnapshot _withoutAddressBlocker(CartSnapshot snapshot) {
    if (_addressId == null) return snapshot;
    final all = snapshot.checkout.blockers;
    final kept = [
      for (final blocker in all)
        if (blocker.code != CheckoutBlockerCode.addressRequired) blocker,
    ];
    if (kept.length == all.length) return snapshot;
    return snapshot.withCheckout(
      CheckoutStatus(
        canPlaceOrder: kept.isEmpty && !snapshot.hasProblems,
        blockers: kept,
      ),
    );
  }

  /// Only `GET /cart/` takes `?address_id=`. Every other cart call answers
  /// with the cart checked against no address (the app never saves one on
  /// the server cart, so a later pin can't silently keep an old address),
  /// and with a saved address chosen that answer wrongly says
  /// ADDRESS_REQUIRED. So after such a change, load the cart again for the
  /// address, quietly: no loading state, the current cart stays on screen,
  /// a failure keeps it, and the ticket order still lets the newest answer
  /// win. Nothing to do without a saved address.
  Future<void> _reloadForAddress() async {
    final addressId = _addressId;
    if (addressId == null || !ref.mounted) return;
    final ticket = ++_issued;
    try {
      _apply(ticket, await _repository.load(addressId: addressId));
    } catch (error) {
      _checkStore(error);
    }
  }

  /// Sets [variant] to a typed [quantity] in one request (bulk orders; 0
  /// removes it). Same rules as [setLineQuantity]: capped at
  /// `orderable_quantity` going up, and never 1 to min - 1. Throws
  /// [CartLimitException] above the cap, or the repository's `ApiError`.
  Future<void> setVariantQuantity(
    CatalogVariant variant,
    int quantity, {
    String? productName,
  }) async {
    final current = state.quantityOf(variant.id);
    final minimum = _minFor(variant);
    final target = quantity < current
        ? _lowered(quantity, minimum)
        : _raised(quantity, minimum);
    if (target == current) return;
    if (target > current && target > variant.maxSelectable) {
      throw CartLimitException(CartLimit.maxReached, variant.maxSelectable);
    }
    await _set(
      variant.id,
      target,
      preview: CartLinePreview.of(variant, productName ?? variant.name),
    );
  }

  /// Sets a cart line's quantity from the cart screen, capped at the
  /// line's `orderable_quantity`. A quantity below the line's minimum per
  /// order becomes 0 (remove) on the way down and the minimum on the way
  /// up.
  Future<void> setLineQuantity(CartLine line, int quantity) async {
    final minimum = _minFor(line.variant);
    final target = quantity < line.quantity
        ? _lowered(quantity, minimum)
        : _raised(quantity, minimum);
    if (target > line.quantity && target > line.orderableQuantity) {
      throw CartLimitException(CartLimit.maxReached, line.orderableQuantity);
    }
    await _set(line.variantId, target);
  }

  /// [quantity] going down: below [minimum] it removes the line.
  static int _lowered(int quantity, int minimum) =>
      quantity < minimum ? 0 : quantity;

  /// [quantity] going up: never between 1 and [minimum] - 1.
  static int _raised(int quantity, int minimum) => quantity <= 0
      ? 0
      : quantity < minimum
      ? minimum
      : quantity;

  Future<void> removeLine(CartLine line) => _set(line.variantId, 0);

  /// The "fix" action on a flagged line (`06 §2.5`): set it to the
  /// server's `orderable_quantity`, which removes it at 0. A line below its
  /// minimum per order goes up to the minimum.
  Future<void> fixLine(CartLine line) => switch (line.issue?.code) {
    null => Future.value(),
    CartIssueCode.minQtyRequired when line.orderableQuantity > 0 => _set(
      line.variantId,
      _minFor(line.variant),
    ),
    _ => _set(line.variantId, line.orderableQuantity),
  };

  /// Empties the cart (store change). No reload for the address here: the
  /// location (and its address) is changing, and the cart reloads for the
  /// new one right after.
  Future<void> clear() async {
    _serverMin.clear();
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
      _apply(ticket, _withoutAddressBlocker(await call(_repository)));
    } catch (error) {
      _checkStore(error);
      rethrow;
    } finally {
      if (ref.mounted) state = state.copyWith(updating: false);
    }
    await _reloadForAddress();
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
        _withoutAddressBlocker(
          await _repository.setQuantity(variantId, quantity, preview: preview),
        ),
      );
    } catch (error) {
      _checkStore(error);
      _learnMin(variantId, error);
      rethrow;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(pending: {...state.pending}..remove(variantId));
      }
    }
    // After the quantity box is free again: no extra wait per change.
    await _reloadForAddress();
  }
}

final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

/// The cart follows `X-Store-Id` (`06 §2.5`): reload it when the store, or
/// its generation after `STORE_NOT_FOUND`, changes. Watched by the app
/// widget; kept outside [CartController] so the cart doesn't depend on the
/// delivery state (which reads the cart: a circular dependency).
final cartStoreSyncProvider = Provider<void>((ref) {
  ref.listen(storeScopeProvider, (previous, next) {
    // A cart not built yet loads by itself when first read: reloading it
    // here would build it and send a second request.
    if (previous != next && ref.exists(cartProvider)) {
      ref.read(cartProvider.notifier).refresh();
    }
  });
});
