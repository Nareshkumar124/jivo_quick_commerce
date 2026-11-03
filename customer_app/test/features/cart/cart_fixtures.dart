import 'dart:async';

import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';

/// A cart line as the server would send it.
CartLine cartLine({
  int id = 1,
  int variantId = 101,
  String name = 'Jivo Canola Oil',
  String variantName = '1 L',
  String price = '249.00',
  String mrp = '299.00',
  int quantity = 2,
  String lineTotal = '498.00',
  int orderable = 5,
  CartLineIssue issue = CartLineIssue.none,
  int? available,
}) => CartLine(
  id: id,
  variantId: variantId,
  productName: name,
  variantName: variantName,
  sellingPrice: price,
  mrp: mrp,
  quantity: quantity,
  lineTotal: lineTotal,
  orderableQuantity: orderable,
  issue: issue,
  availableQuantity: available,
);

/// A bill whose numbers deliberately do **not** add up: any screen that
/// sums or derives money instead of rendering these strings fails its test.
const inconsistentBill = CartBill(
  mrpTotal: '598.00',
  itemTotal: '498.00',
  productDiscount: '100.00',
  couponDiscount: '0.00',
  deliveryFee: '0.00',
  smallCartFee: '0.00',
  handlingFee: '5.00',
  tip: '0.00',
  grandTotal: '999.00',
);

CartSnapshot cartSnapshot({
  List<CartLine>? lines,
  CartBill bill = inconsistentBill,
  AppliedCoupon? coupon,
  MinimumOrder? minimumOrder = const MinimumOrder(met: true, amount: '49.00'),
  bool codAvailable = true,
  int? addressId = 1,
}) => CartSnapshot.fromLines(
  lines: lines ?? [cartLine()],
  bill: bill,
  coupon: coupon,
  minimumOrder: minimumOrder,
  codAvailable: codAvailable,
  addressId: addressId,
);

/// Returns [snapshot] for every call; [gate], when set, holds each call.
class StubCartRepository implements CartRepository {
  StubCartRepository(this.snapshot);

  CartSnapshot snapshot;
  Object? loadError;
  Completer<void>? gate;
  final calls = <String>[];
  final updates = <CartUpdate>[];

  Future<CartSnapshot> _answer(String call) async {
    calls.add(call);
    final wait = gate;
    if (wait != null) await wait.future;
    return snapshot;
  }

  @override
  Future<CartSnapshot> load({int? addressId}) async {
    calls.add('load:$addressId');
    final error = loadError;
    if (error != null) throw error;
    return snapshot;
  }

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) => _answer('set:$variantId:$quantity');

  @override
  Future<CartSnapshot> clear() => _answer('clear');

  @override
  Future<List<CouponOffer>> coupons() async => const [];

  @override
  Future<CartSnapshot> applyCoupon(String code) => _answer('coupon:$code');

  @override
  Future<CartSnapshot> removeCoupon() => _answer('coupon:remove');

  @override
  Future<CartSnapshot> update(CartUpdate update) {
    updates.add(update);
    return _answer('update');
  }
}

/// A catalog variant for the fake backend's preview (price `249.00`).
CatalogVariant oil({
  int id = 101,
  int orderable = 5,
  String price = '249.00',
}) => CatalogVariant(
  id: id,
  name: '1 L',
  sellingPrice: price,
  mrp: '299.00',
  stockStatus: StockStatus.inStock,
  orderableQuantity: orderable,
  maxQtyPerOrder: 5,
);
