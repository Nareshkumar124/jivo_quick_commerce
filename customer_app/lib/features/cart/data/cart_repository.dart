import 'package:jivo_core/jivo_core.dart';

import '../domain/cart.dart';

/// The customer's server-side cart for the selected store (`03 §2.8`,
/// `06 §2.5`; every call carries `X-Store-Id`). Every call returns the whole
/// cart with its fresh bill, so the screens never patch money locally.
///
/// Implementations throw `ApiError` (e.g. `STOCK_UNAVAILABLE`,
/// `MAX_QTY_EXCEEDED`, the `COUPON_*` codes, `STORE_NOT_FOUND`).
abstract interface class CartRepository {
  /// `GET /cart/?address_id=`: lines, stock flags and the bill. The bill
  /// is computed for [addressId] when given.
  Future<CartSnapshot> load({int? addressId});

  /// `POST /cart/items/ {variant_id, quantity}`: **sets** the line's
  /// quantity (not an increment, so a retried request never doubles it);
  /// 0 removes the line. [preview] is for the fake backend only.
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

/// Staging and prod until the cart is enabled there (S3-B): there is no
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
