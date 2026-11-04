import 'dart:async';

import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/orders/domain/order.dart';

/// A cart line as the server would send it. [orderable] is the variant's
/// `orderable_quantity`; [issue] its flag.
CartLine cartLine({
  int id = 1,
  int variantId = 101,
  String name = 'Jivo Canola Oil',
  String variantName = '1 L',
  String price = '249.00',
  String mrp = '299.00',
  int quantity = 2,
  String lineTotal = '498.00',
  String lineMrpTotal = '598.00',
  int orderable = 5,
  CartIssueCode? issue,
}) => CartLine(
  id: id,
  productName: name,
  variant: CatalogVariant(
    id: variantId,
    name: variantName,
    sellingPrice: price,
    mrp: mrp,
    stockStatus: orderable > 0 ? StockStatus.inStock : StockStatus.outOfStock,
    orderableQuantity: orderable,
    maxQtyPerOrder: 5,
  ),
  quantity: quantity,
  lineMrpTotal: lineMrpTotal,
  lineTotal: lineTotal,
  issue: issue == null ? null : CartLineIssue(code: issue, message: 'x'),
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
  totalSavings: '0.00',
);

const okCheckout = CheckoutStatus(canPlaceOrder: true);

const bothMethods = [
  PaymentOption(method: PaymentMethod.online, available: true),
  PaymentOption(method: PaymentMethod.cod, available: true),
];

CartSnapshot cartSnapshot({
  List<CartLine>? lines,
  CartBill bill = inconsistentBill,
  AppliedCoupon? coupon,
  CartThresholds thresholds = const CartThresholds(minOrderValue: '49.00'),
  CheckoutStatus checkout = okCheckout,
  List<PaymentOption> paymentOptions = bothMethods,
  int? addressId = 1,
}) {
  final all = lines ?? [cartLine()];
  return CartSnapshot.fromLines(
    lines: all,
    itemCount: all.fold(0, (sum, line) => sum + line.quantity),
    bill: bill,
    coupon: coupon,
    thresholds: thresholds,
    checkout: checkout,
    paymentOptions: paymentOptions,
    addressId: addressId,
  );
}

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
