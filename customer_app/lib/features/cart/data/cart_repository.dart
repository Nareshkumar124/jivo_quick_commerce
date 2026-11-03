import 'package:jivo_core/jivo_core.dart';

import '../domain/cart.dart';

/// The customer's server-side cart for the selected store (`03 §2.8`,
/// `06 §2.5`; every call carries `X-Store-Id`). Every write returns the
/// whole cart with its fresh bill, so the screens never patch money
/// locally. TODO(api): confirm the write endpoints return the full cart.
///
/// Implementations throw `ApiError` (e.g. `STOCK_UNAVAILABLE`,
/// `MAX_QTY_EXCEEDED`, the `COUPON_*` codes).
abstract interface class CartRepository {
  /// `GET /cart/?address_id=`: lines, stock flags and the bill. The bill
  /// is computed for [addressId] when given.
  Future<CartSnapshot> load({int? addressId});

  /// Sets [variantId] to [quantity]; 0 removes the line.
  ///
  /// The stepper works in variant ids, the API in cart line ids: `POST
  /// /cart/items/ {variant_id, quantity}` when the variant has no line yet,
  /// `PATCH /cart/items/{line_id}/ {quantity}` to change it and `DELETE
  /// /cart/items/{line_id}/` at 0. [preview] is for the fake cart only.
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  });

  /// `DELETE /cart/` (e.g. when the store changes, `03 §2.3`).
  Future<CartSnapshot> clear();

  /// `GET /cart/coupons/`: coupons with eligibility and savings for this
  /// cart.
  Future<List<CouponOffer>> coupons();

  /// `POST /cart/coupon/ {code}`.
  Future<CartSnapshot> applyCoupon(String code);

  /// `DELETE /cart/coupon/`.
  Future<CartSnapshot> removeCoupon();

  /// `PATCH /cart/`: tip, instructions and the delivery address.
  Future<CartSnapshot> update(CartUpdate update);
}

/// Staging and prod until the Phase 3 cart API is wired (S3-A): there is no
/// cart yet. The UI checks `cartAvailableProvider` and never calls this.
class UnavailableCartRepository implements CartRepository {
  const UnavailableCartRepository();

  static Never _unavailable() =>
      throw const ApiError(code: ApiErrorCode.serviceUnavailable);

  @override
  Future<CartSnapshot> load({int? addressId}) async => CartSnapshot.empty;

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) => _unavailable();

  @override
  Future<CartSnapshot> clear() async => CartSnapshot.empty;

  @override
  Future<List<CouponOffer>> coupons() => _unavailable();

  @override
  Future<CartSnapshot> applyCoupon(String code) => _unavailable();

  @override
  Future<CartSnapshot> removeCoupon() => _unavailable();

  @override
  Future<CartSnapshot> update(CartUpdate update) => _unavailable();
}
