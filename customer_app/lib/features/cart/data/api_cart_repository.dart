import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' as api;
import 'package:jivo_core/jivo_core.dart';

import '../../catalog/data/api_catalog_repository.dart' show variantFromApi;
import '../../orders/data/api_order_repository.dart' show paymentMethodFromApi;
import '../domain/cart.dart';
import 'cart_repository.dart';

/// The server cart on the generated client (`06 §2.5`). Every call carries
/// the serving store as `X-Store-Id`; [storeId] reads it at call time.
class ApiCartRepository implements CartRepository {
  ApiCartRepository(this._api, this._storeId);

  final api.JivoApi _api;
  final int? Function() _storeId;

  api.CartApi get _cart => _api.getCartApi();

  /// Without a store there is no cart: treat it like a store that is gone,
  /// so the location is checked again.
  int get _store =>
      _storeId() ??
      (throw const ApiError(code: ApiErrorCode.storeNotFound, statusCode: 404));

  Future<CartSnapshot> _call(Future<Response<api.Cart>> Function() call) =>
      _guard(() async => cartFromApi((await call()).data!));

  @override
  Future<CartSnapshot> load({int? addressId}) =>
      _call(() => _cart.cartRetrieve(xStoreId: _store, addressId: addressId));

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) => _call(
    () => _cart.cartItemsAdd(
      xStoreId: _store,
      cartItemAddRequest: api.CartItemAddRequest(
        variantId: variantId,
        quantity: quantity < 0 ? 0 : quantity,
      ),
    ),
  );

  @override
  Future<CartSnapshot> clear() =>
      _call(() => _cart.cartClear(xStoreId: _store));

  @override
  Future<List<CouponOffer>> coupons() => _guard(() async {
    final list = (await _cart.cartCouponsList(xStoreId: _store)).data!;
    return [for (final offer in list.results) _offer(offer)];
  });

  @override
  Future<CartSnapshot> applyCoupon(String code) => _call(
    () => _cart.cartCouponApply(
      xStoreId: _store,
      couponApplyRequest: api.CouponApplyRequest(code: code.trim()),
    ),
  );

  @override
  Future<CartSnapshot> removeCoupon() =>
      _call(() => _cart.cartCouponRemove(xStoreId: _store));

  @override
  Future<CartSnapshot> update(CartUpdate update) {
    final instructions = update.instructions;
    return _call(
      () => _cart.cartUpdate(
        xStoreId: _store,
        patchedCartUpdateRequest: api.PatchedCartUpdateRequest(
          tip: update.tip,
          addressId: update.addressId,
          instructions: instructions == null
              ? null
              : api.DeliveryInstructionsRequest(
                  chips: [for (final tag in instructions.tags) _chipToApi(tag)],
                  note: instructions.note.trim(),
                ),
        ),
      ),
    );
  }
}

/// `Cart` as the app's [CartSnapshot]: the server's values, unchanged.
CartSnapshot cartFromApi(api.Cart c) => CartSnapshot.fromLines(
  lines: [for (final line in c.items) _line(line)],
  itemCount: c.itemCount,
  bill: billFromApi(c.bill),
  coupon: switch (c.coupon) {
    null => null,
    final coupon => AppliedCoupon(
      code: coupon.code,
      title: coupon.title,
      discount: coupon.discount,
      isApplicable: coupon.isApplicable,
      message: coupon.message,
    ),
  },
  tip: c.tip,
  instructions: DeliveryInstructions(
    tags: {for (final chip in c.instructions.chips) ?_chipFromApi(chip)},
    note: c.instructions.note,
  ),
  addressId: c.address?.id,
  thresholds: CartThresholds(
    minOrderValue: c.thresholds.minOrderValue,
    amountToMinOrder: c.thresholds.amountToMinOrder,
    freeDeliveryThreshold: c.thresholds.freeDeliveryThreshold,
    amountToFreeDelivery: c.thresholds.amountToFreeDelivery,
  ),
  paymentOptions: [
    for (final option in c.paymentMethods)
      if (paymentMethodFromApi(option.method) case final method?)
        PaymentOption(
          method: method,
          available: option.isAvailable,
          reason: switch (option.unavailableReason) {
            null => null,
            api.PaymentUnavailableReasonEnum.COD_DISABLED =>
              PaymentUnavailableReason.codDisabled,
            api.PaymentUnavailableReasonEnum.ABOVE_LIMIT =>
              PaymentUnavailableReason.aboveLimit,
            api.PaymentUnavailableReasonEnum.NOT_ALLOWED =>
              PaymentUnavailableReason.notAllowed,
            _ => PaymentUnavailableReason.unknown,
          },
          message: option.message,
        ),
  ],
  checkout: CheckoutStatus(
    canPlaceOrder: c.checkout.canPlaceOrder,
    blockers: [
      for (final blocker in c.checkout.blockers)
        CheckoutBlocker(
          code: _blockerCode(blocker.code),
          message: blocker.message,
        ),
    ],
  ),
  storeOpen: c.store.isOpen,
);

/// `Bill` as the app's [CartBill] (the cart's and the order's bill).
CartBill billFromApi(api.Bill b) => CartBill(
  mrpTotal: b.mrpTotal,
  itemTotal: b.itemTotal,
  productDiscount: b.productDiscount,
  couponDiscount: b.couponDiscount,
  deliveryFee: b.deliveryFee,
  smallCartFee: b.smallCartFee,
  handlingFee: b.handlingFee,
  tip: b.tip,
  grandTotal: b.grandTotal,
  totalSavings: b.totalSavings,
);

CartLine _line(api.CartLine l) => CartLine(
  id: l.id,
  productId: l.product.id,
  productSlug: l.product.slug,
  productName: l.product.name,
  variant: variantFromApi(l.variant),
  quantity: l.quantity,
  lineMrpTotal: l.lineMrpTotal,
  lineTotal: l.lineTotal,
  issue: switch (l.issue) {
    null => null,
    final issue => CartLineIssue(
      code: switch (issue.code) {
        api.CartLineIssueCodeEnum.OUT_OF_STOCK => CartIssueCode.outOfStock,
        api.CartLineIssueCodeEnum.QUANTITY_UNAVAILABLE =>
          CartIssueCode.quantityUnavailable,
        _ => CartIssueCode.unknown,
      },
      message: issue.message,
    ),
  },
);

CheckoutBlockerCode _blockerCode(api.CheckoutBlockerCodeEnum code) =>
    switch (code) {
      api.CheckoutBlockerCodeEnum.CART_EMPTY => CheckoutBlockerCode.cartEmpty,
      api.CheckoutBlockerCodeEnum.ADDRESS_REQUIRED =>
        CheckoutBlockerCode.addressRequired,
      api.CheckoutBlockerCodeEnum.NOT_SERVICEABLE =>
        CheckoutBlockerCode.notServiceable,
      api.CheckoutBlockerCodeEnum.STORE_CLOSED =>
        CheckoutBlockerCode.storeClosed,
      api.CheckoutBlockerCodeEnum.STOCK_UNAVAILABLE =>
        CheckoutBlockerCode.stockUnavailable,
      api.CheckoutBlockerCodeEnum.MIN_ORDER_NOT_MET =>
        CheckoutBlockerCode.minOrderNotMet,
      api.CheckoutBlockerCodeEnum.COUPON_INVALID =>
        CheckoutBlockerCode.couponInvalid,
      api.CheckoutBlockerCodeEnum.COUPON_EXPIRED =>
        CheckoutBlockerCode.couponExpired,
      api.CheckoutBlockerCodeEnum.COUPON_NOT_ELIGIBLE =>
        CheckoutBlockerCode.couponNotEligible,
      api.CheckoutBlockerCodeEnum.COUPON_USAGE_EXCEEDED =>
        CheckoutBlockerCode.couponUsageExceeded,
      _ => CheckoutBlockerCode.unknown,
    };

CouponOffer _offer(api.CouponOffer o) => CouponOffer(
  code: o.code,
  title: o.title,
  description: o.description,
  isEligible: o.isEligible,
  isApplied: o.isApplied,
  savings: o.savings,
  ineligibility: switch (o.ineligibleReason) {
    null => null,
    api.CouponIneligibleReasonEnum.MIN_ORDER_VALUE =>
      CouponIneligibility.minOrderValue,
    api.CouponIneligibleReasonEnum.FIRST_ORDER_ONLY =>
      CouponIneligibility.firstOrderOnly,
    api.CouponIneligibleReasonEnum.NO_ELIGIBLE_ITEMS =>
      CouponIneligibility.noEligibleItems,
    api.CouponIneligibleReasonEnum.STORE => CouponIneligibility.store,
    _ => CouponIneligibility.unknown,
  },
  message: o.message,
  amountToUnlock: o.amountToUnlock,
  endsAt: o.endsAt,
);

InstructionTag? _chipFromApi(
  api.DeliveryInstructionChipEnum chip,
) => switch (chip) {
  api.DeliveryInstructionChipEnum.DONT_RING_BELL => InstructionTag.dontRingBell,
  api.DeliveryInstructionChipEnum.LEAVE_AT_DOOR => InstructionTag.leaveAtDoor,
  api.DeliveryInstructionChipEnum.AVOID_CALLING => InstructionTag.avoidCalling,
  _ => null,
};

api.DeliveryInstructionChipEnum _chipToApi(InstructionTag tag) => switch (tag) {
  InstructionTag.dontRingBell => api.DeliveryInstructionChipEnum.DONT_RING_BELL,
  InstructionTag.leaveAtDoor => api.DeliveryInstructionChipEnum.LEAVE_AT_DOOR,
  InstructionTag.avoidCalling => api.DeliveryInstructionChipEnum.AVOID_CALLING,
};

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}
