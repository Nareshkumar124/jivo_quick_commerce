import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog_models.dart';
import '../../orders/domain/order.dart';

/// The cart as the server reports it (`03 §2.8`, `06 §2.5`, schema `Cart`).
///
/// Money is never computed in the app (`08 §6`). Every amount here is the
/// server's decimal string (`"249.00"`), shown only with `formatRupees`.
/// Totals, discounts, fees, savings, the "add ₹X more" amounts and whether
/// checkout is allowed all come from the server. `ApiCartRepository` maps
/// the generated `jivo_api` models into these types, so widgets don't depend
/// on the generated client.
@immutable
class CartSnapshot {
  const CartSnapshot({
    this.quantities = const {},
    this.itemCount = 0,
    this.itemTotal,
    this.lines = const [],
    this.bill,
    this.coupon,
    this.tip = '0.00',
    this.instructions = DeliveryInstructions.none,
    this.addressId,
    this.thresholds,
    this.paymentOptions = const [],
    this.checkout = CheckoutStatus.unknown,
    this.storeOpen = true,
    this.freeLines = const [],
    this.freeOffer,
  });

  /// A snapshot built from the server's lines: [quantities] is read from
  /// the paid lines only (unit counts, not money). Free lines never reach
  /// the steppers.
  factory CartSnapshot.fromLines({
    required List<CartLine> lines,
    required int itemCount,
    CartBill? bill,
    AppliedCoupon? coupon,
    String tip = '0.00',
    DeliveryInstructions instructions = DeliveryInstructions.none,
    int? addressId,
    CartThresholds? thresholds,
    List<PaymentOption> paymentOptions = const [],
    CheckoutStatus checkout = CheckoutStatus.unknown,
    bool storeOpen = true,
    List<FreeLine> freeLines = const [],
    FreeOffer? freeOffer,
  }) => CartSnapshot(
    quantities: Map.unmodifiable({
      for (final line in lines) line.variantId: line.quantity,
    }),
    itemCount: itemCount,
    itemTotal: bill?.itemTotal,
    lines: List.unmodifiable(lines),
    bill: bill,
    coupon: coupon,
    tip: tip,
    instructions: instructions,
    addressId: addressId,
    thresholds: thresholds,
    paymentOptions: List.unmodifiable(paymentOptions),
    checkout: checkout,
    storeOpen: storeOpen,
    freeLines: List.unmodifiable(freeLines),
    freeOffer: freeOffer,
  );

  static const empty = CartSnapshot();

  /// Quantity per variant id.
  final Map<int, int> quantities;

  /// Units in the cart (`item_count`), for the cart bar.
  final int itemCount;

  /// The server's item total (the cart bar amount), or null when not known.
  final String? itemTotal;

  /// The cart lines, in the order they were added.
  final List<CartLine> lines;

  /// The bill from `compute_bill` (all zeros for an empty cart).
  final CartBill? bill;

  /// The applied coupon, if any.
  final AppliedCoupon? coupon;

  /// The chosen rider tip (`Cart.tip`; kept while the cart is empty).
  final String tip;

  /// What the customer asked the delivery partner to do.
  final DeliveryInstructions instructions;

  /// The saved address the cart is checked against (`Cart.address.id`).
  final int? addressId;

  /// The store's thresholds and how far the cart is from them.
  final CartThresholds? thresholds;

  /// ONLINE then COD, each with its availability for this cart.
  final List<PaymentOption> paymentOptions;

  /// Whether the order can be placed now, and what stops it.
  final CheckoutStatus checkout;

  /// `Cart.store.is_open`.
  final bool storeOpen;

  /// The free cartons on this cart (`free_lines`, ADR 0002): the volume
  /// offer's and a reward's, each at ₹0. The server picks them; the app
  /// only shows them, and they never count as paid units.
  final List<FreeLine> freeLines;

  /// The store's "buy N get 1 free" offer and how far the cart is from the
  /// next free carton (`free_offer`); null when the store has no offer.
  final FreeOffer? freeOffer;

  /// No paid units (`item_count` is 0). A cart can still hold a reward's
  /// free line then: see [hasContent].
  bool get isEmpty => itemCount == 0;

  /// Something to show on the cart screen: paid units, or a free line
  /// (e.g. a reward used before adding anything).
  bool get hasContent => !isEmpty || freeLines.isNotEmpty;

  int quantityOf(int variantId) => quantities[variantId] ?? 0;

  /// The line for [variantId], or null.
  CartLine? lineFor(int variantId) {
    for (final line in lines) {
      if (line.variantId == variantId) return line;
    }
    return null;
  }

  /// Lines the server flagged (`CartLine.issue`), to fix before checkout.
  List<CartLine> get problemLines =>
      lines.where((line) => line.issue != null).toList();

  bool get hasProblems => lines.any((line) => line.issue != null);

  /// Lines whose store price changed since the customer last saw it
  /// (`previous_selling_price`, CA-19). Not a problem: checkout stays open.
  int get priceChangedLines => lines.where((line) => line.priceChanged).length;

  /// Whether the server offers [method] for this cart.
  bool offers(PaymentMethod method) => paymentOptions.any(
    (option) => option.method == method && option.available,
  );

  /// Cash on Delivery is shown only when eligible (`03 §2.9`).
  bool get codAvailable => offers(PaymentMethod.cod);

  /// This snapshot with another [checkout] status (everything else kept).
  CartSnapshot withCheckout(CheckoutStatus checkout) => CartSnapshot(
    quantities: quantities,
    itemCount: itemCount,
    itemTotal: itemTotal,
    lines: lines,
    bill: bill,
    coupon: coupon,
    tip: tip,
    instructions: instructions,
    addressId: addressId,
    thresholds: thresholds,
    paymentOptions: paymentOptions,
    checkout: checkout,
    storeOpen: storeOpen,
    freeLines: freeLines,
    freeOffer: freeOffer,
  );
}

/// Why a carton is free (`free_lines[].source`, `OrderItem.free_source`).
enum FreeLineSource {
  /// "Buy 10 get 1 free": added by the server for every N paid cartons.
  volumeOffer('VOLUME_OFFER'),

  /// A free-carton reward the customer used (welcome or referral).
  reward('REWARD'),

  /// A source this build doesn't know (a newer server).
  unknown(null);

  const FreeLineSource(this.wireValue);

  final String? wireValue;

  static FreeLineSource fromWire(String? value) => values.firstWhere(
    (source) => source.wireValue != null && source.wireValue == value,
    orElse: () => unknown,
  );
}

/// A free carton line (ADR 0002): in the cart (`free_lines`) and on an
/// order (its `is_free` items). Always ₹0; [mrp] and [value] are the
/// server's strings for the struck-out price, never added up here.
@immutable
class FreeLine {
  const FreeLine({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.quantity,
    required this.mrp,
    required this.value,
    required this.source,
    this.productId,
    this.productSlug,
    this.imageUrl,
    this.quantityUnavailable = 0,
  });

  final int variantId;
  final int? productId;
  final String? productSlug;
  final String productName;

  /// e.g. "1 L × 12".
  final String variantName;
  final String? imageUrl;
  final int quantity;

  /// The MRP of one carton.
  final String mrp;

  /// The server's MRP × [quantity] (what the customer gets for free).
  final String value;
  final FreeLineSource source;

  /// Orders only: free cartons the store couldn't supply (dropped at ₹0,
  /// nothing to refund, ADR 0002 rule 6).
  final int quantityUnavailable;
}

/// The store's fixed free-carton size (ADR 0003, `PricingConfig.
/// free_unit_variant`): every free carton, from the volume offer or a
/// reward, is this variant. Names as the server sends them.
@immutable
class FreeVariant {
  const FreeVariant({
    required this.id,
    required this.name,
    required this.productName,
  });

  final int id;

  /// e.g. "1 L × 12".
  final String name;
  final String productName;

  @override
  bool operator ==(Object other) =>
      other is FreeVariant &&
      other.id == id &&
      other.name == name &&
      other.productName == productName;

  @override
  int get hashCode => Object.hash(id, name, productName);
}

/// The store's volume offer on this cart (`free_offer`, ADR 0002): 1 free
/// carton for every [every] paid cartons. Every number and text is the
/// server's.
@immutable
class FreeOffer {
  const FreeOffer({
    required this.every,
    required this.paidUnits,
    required this.freeUnits,
    this.unitsToNextFree,
    this.message = '',
    this.notice,
    this.freeVariant,
  });

  /// Paid cartons per free carton (e.g. 10).
  final int every;

  /// Paid cartons counted for the offer (free ones never count).
  final int paidUnits;

  /// Free cartons this cart gets now.
  final int freeUnits;

  /// Paid cartons still to add for the next free one; null when unknown.
  final int? unitsToNextFree;

  /// The server's nudge, e.g. "Add 8 more cartons to get 1 more free".
  final String message;

  /// Set when an earned free carton can't be supplied (no stock): shown as
  /// a notice, never a blocker.
  final String? notice;

  /// The size every free carton is (ADR 0003); null when the store has no
  /// fixed free size (the ADR 0002 cheapest-size rule).
  final FreeVariant? freeVariant;
}

/// `CartLineIssueCodeEnum`.
enum CartIssueCode {
  /// Nothing can be ordered: remove the line.
  outOfStock,

  /// Fewer units can be ordered: reduce to `variant.orderable_quantity`.
  quantityUnavailable,

  /// Below `variant.min_qty_per_order` (e.g. the minimum was raised after
  /// the line was added): raise it to the minimum, or remove it.
  minQtyRequired,

  /// A code this build doesn't know.
  unknown,
}

/// Why a line can't be ordered as it is (`CartLineIssue`).
@immutable
class CartLineIssue {
  const CartLineIssue({required this.code, required this.message});

  final CartIssueCode code;

  /// The server's display text; used only when [code] is unknown.
  final String message;
}

/// One cart line (`CartLine`): the variant priced and checked against stock
/// at the store right now.
@immutable
class CartLine {
  const CartLine({
    required this.id,
    required this.productName,
    required this.variant,
    required this.quantity,
    required this.lineMrpTotal,
    required this.lineTotal,
    this.productId,
    this.productSlug,
    this.issue,
    this.pricePerUnit,
    this.priceTier,
    this.nextTierPrice,
    this.previousSellingPrice,
  });

  /// The server's line id.
  final int id;
  final int? productId;
  final String? productSlug;
  final String productName;

  /// The variant with its current price and stock (`VariantSummary`).
  final CatalogVariant variant;
  final int quantity;

  /// The server's `mrp × quantity` and `price_per_unit × quantity`.
  final String lineMrpTotal;
  final String lineTotal;

  /// The price each unit is billed at (`price_per_unit`): the volume
  /// tier's price when [priceTier] is set, else the selling price. Read it
  /// through [billedPrice].
  final String? pricePerUnit;

  /// The volume tier the cart reached for this line (`price_tier`); null
  /// when the normal price applies.
  final PriceTier? priceTier;

  /// This line's lower unit price once the cart reaches
  /// `thresholds.next_price_tier` (`next_tier_price`); null when that tier
  /// doesn't lower it.
  final String? nextTierPrice;

  /// The store price the customer last saw for this line, when it differs
  /// from today's [sellingPrice] (`previous_selling_price`, API #56,
  /// CA-19); null when unchanged. Display only: the bill already uses
  /// today's price, and the server clears it on the line's next quantity
  /// set.
  final String? previousSellingPrice;

  /// Whether the server flagged a price change on this line.
  bool get priceChanged => previousSellingPrice != null;

  /// The server's billed unit price. The API always sends
  /// `price_per_unit`; only a line built without it (older fixtures) falls
  /// back to the variant's selling price, which the server bills then.
  String get billedPrice => pricePerUnit ?? variant.sellingPrice;

  /// Null when the line is fine.
  final CartLineIssue? issue;

  int get variantId => variant.id;
  String get variantName => variant.name;
  String get sellingPrice => variant.sellingPrice;
  String get mrp => variant.mrp;
  String? get imageUrl => variant.imageUrl;

  /// The stepper cap and the fix target: the server's
  /// `orderable_quantity` (0 when it can't be ordered).
  int get orderableQuantity => variant.maxSelectable;

  /// The variant's `min_qty_per_order`: minus at this quantity removes the
  /// line.
  int get minQty => variant.minQty;
}

/// The bill from `cart.services.compute_bill` (`08 §6.2`, schema `Bill`),
/// as sent. The same shape is the order's bill.
@immutable
class CartBill {
  const CartBill({
    required this.mrpTotal,
    required this.itemTotal,
    required this.productDiscount,
    required this.couponDiscount,
    required this.deliveryFee,
    required this.smallCartFee,
    required this.handlingFee,
    required this.tip,
    required this.grandTotal,
    required this.totalSavings,
    this.freeItemsValue = '0.00',
  });

  final String mrpTotal;
  final String itemTotal;
  final String productDiscount;
  final String couponDiscount;

  /// `"0.00"` shows as FREE.
  final String deliveryFee;
  final String smallCartFee;
  final String handlingFee;
  final String tip;

  /// **To pay.**
  final String grandTotal;

  /// "You save ₹X": the server's product + coupon discount, plus the free
  /// cartons' value (ADR 0002).
  final String totalSavings;

  /// The MRP value of the free cartons (`free_items_value`, ADR 0002).
  /// Not part of the item total or the amount to pay; `"0.00"` when none.
  final String freeItemsValue;
}

/// The store's thresholds and how far the cart is from them
/// (`CartThresholds`), computed by the server.
@immutable
class CartThresholds {
  const CartThresholds({
    required this.minOrderValue,
    this.amountToMinOrder,
    this.freeDeliveryThreshold,
    this.amountToFreeDelivery,
    this.minOrderUnits = 0,
    this.unitsToMinOrder,
    this.orderUnitLabel = '',
    this.tierUnits = 0,
    this.nextPriceTier,
  });

  final String minOrderValue;

  /// Item value still needed for the minimum; null when reached.
  final String? amountToMinOrder;
  final String? freeDeliveryThreshold;

  /// For "Add ₹X more for FREE delivery"; null when delivery is free.
  final String? amountToFreeDelivery;

  /// The fewest units (any mix of products) an order must have
  /// (`min_order_units`); 0 = no such rule.
  final int minOrderUnits;

  /// Units still needed for [minOrderUnits] (`units_to_min_order`); null
  /// when met or when there is no such rule. While set, checkout is blocked
  /// (`MIN_UNITS_NOT_MET`) and the cart shows "Add N more".
  final int? unitsToMinOrder;

  /// What a unit is called (`order_unit_label`, e.g. "cartons"); empty when
  /// the server sends none.
  final String orderUnitLabel;

  /// Units that choose the volume price tier (`tier_units`): every line
  /// with price tiers, any mix; 0 when no line has tiers.
  final int tierUnits;

  /// The next tier at which a line's price drops (`next_price_tier`), for
  /// "Add 3 more boxes to get ₹87/box"; null at the top tier or when no
  /// line has tiers.
  final NextPriceTier? nextPriceTier;
}

/// The next volume tier (`NextPriceTier`): each line's new price there is
/// its [CartLine.nextTierPrice].
@immutable
class NextPriceTier {
  const NextPriceTier({
    required this.minOrderUnits,
    required this.unitsToNextTier,
  });

  /// The tier units the lower prices start at.
  final int minOrderUnits;

  /// Units still to add (any tiered item) to reach it.
  final int unitsToNextTier;
}

/// `PaymentUnavailableReasonEnum`.
enum PaymentUnavailableReason { codDisabled, aboveLimit, notAllowed, unknown }

/// One payment method with its availability (`PaymentOption`).
@immutable
class PaymentOption {
  const PaymentOption({
    required this.method,
    required this.available,
    this.reason,
    this.message,
  });

  final PaymentMethod method;
  final bool available;
  final PaymentUnavailableReason? reason;
  final String? message;
}

/// `CheckoutBlockerCodeEnum`.
enum CheckoutBlockerCode {
  cartEmpty,
  addressRequired,
  notServiceable,

  /// The account has no phone and the address no receiver phone.
  phoneRequired,
  storeClosed,
  stockUnavailable,

  /// A line is below its variant's `min_qty_per_order`.
  minQtyRequired,
  minOrderNotMet,

  /// Fewer units in the order than the store's `min_order_units`.
  minUnitsNotMet,
  couponInvalid,
  couponExpired,
  couponNotEligible,
  couponUsageExceeded,

  /// A code this build doesn't know: its server message is shown.
  unknown,
}

/// Something that stops the order now (`CheckoutBlocker`).
@immutable
class CheckoutBlocker {
  const CheckoutBlocker({required this.code, required this.message});

  final CheckoutBlockerCode code;

  /// The server's display text; used only when [code] is unknown.
  final String message;
}

/// `CheckoutStatus`: enable checkout only when [canPlaceOrder].
@immutable
class CheckoutStatus {
  const CheckoutStatus({required this.canPlaceOrder, this.blockers = const []});

  /// Before the first answer from the server.
  static const unknown = CheckoutStatus(canPlaceOrder: false);

  final bool canPlaceOrder;

  /// Most important first.
  final List<CheckoutBlocker> blockers;
}

/// What a coupon gives (`DiscountTypeEnum`).
enum CouponDiscountType {
  flat('FLAT'),
  percent('PERCENT'),

  /// Free cartons (ADR 0002, 0003): a reward of `free_quantity` cartons,
  /// of the store's fixed size, or of a chosen size (`free_variant_id`)
  /// when the store has none.
  freeUnit('FREE_UNIT'),

  /// A type this build doesn't know (a newer server).
  unknown(null);

  const CouponDiscountType(this.wireValue);

  final String? wireValue;

  static CouponDiscountType fromWire(String? value) => values.firstWhere(
    (type) => type.wireValue != null && type.wireValue == value,
    orElse: () => unknown,
  );
}

/// Why a personal coupon (a reward) was given (`Coupon.source`, ADR 0002).
enum RewardSource {
  /// The one-time gift on the first login of a new account.
  welcome('WELCOME'),

  /// The customer referred a friend whose first order was delivered.
  referralReferrer('REFERRAL_REFERRER'),

  /// The customer joined with a friend's code.
  referralReferred('REFERRAL_REFERRED'),

  /// Not a reward (an ordinary coupon).
  none('NONE'),

  /// A source this build doesn't know.
  unknown(null);

  const RewardSource(this.wireValue);

  final String? wireValue;

  static RewardSource fromWire(String? value) => values.firstWhere(
    (source) => source.wireValue != null && source.wireValue == value,
    orElse: () => unknown,
  );

  bool get isReferral => this == referralReferrer || this == referralReferred;
}

/// The coupon on the cart (`AppliedCoupon`).
@immutable
class AppliedCoupon {
  const AppliedCoupon({
    required this.code,
    required this.title,
    required this.discount,
    this.isApplicable = true,
    this.message,
    this.discountType = CouponDiscountType.unknown,
    this.source = RewardSource.none,
    this.freeVariantId,
    this.freeQuantity,
  });

  final String code;
  final String title;

  /// The discount it gives this cart now (`"0.00"` when it doesn't apply).
  final String discount;

  /// False when the cart no longer qualifies: it stays applied, gives
  /// nothing, and checkout is blocked until it is removed or the cart
  /// qualifies again.
  final bool isApplicable;

  /// The server's reason when it doesn't apply.
  final String? message;

  final CouponDiscountType discountType;
  final RewardSource source;

  /// The free carton's size (`free_variant_id`): the store's fixed size
  /// (ADR 0003) or the one chosen.
  final int? freeVariantId;

  /// Free cartons this reward gives (`free_quantity`, ADR 0003); null for
  /// other coupons, or from a server before ADR 0003.
  final int? freeQuantity;

  /// A free-carton reward: it adds a free line instead of a ₹ discount.
  bool get isFreeCarton => discountType == CouponDiscountType.freeUnit;
}

/// `CouponIneligibleReasonEnum`.
enum CouponIneligibility {
  minOrderValue,
  firstOrderOnly,
  noEligibleItems,
  store,
  unknown,
}

/// One coupon in the coupon sheet (`CouponOffer`). Expired and used-up
/// coupons are not listed by the server.
@immutable
class CouponOffer {
  const CouponOffer({
    required this.code,
    required this.title,
    required this.description,
    required this.isEligible,
    this.isApplied = false,
    this.savings,
    this.ineligibility,
    this.message,
    this.amountToUnlock,
    this.endsAt,
    this.isPersonal = false,
    this.minOrderValue,
    this.discountType = CouponDiscountType.unknown,
    this.source = RewardSource.none,
    this.freeVariantId,
    this.freeQuantity,
  });

  final String code;
  final String title;

  /// Terms in one line.
  final String description;
  final bool isEligible;

  /// The coupon on the cart now.
  final bool isApplied;

  /// What it saves on this cart now, when eligible.
  final String? savings;
  final CouponIneligibility? ineligibility;

  /// The server's reason text, used for unknown reasons.
  final String? message;

  /// For [CouponIneligibility.minOrderValue]: item value still needed.
  final String? amountToUnlock;

  /// UTC expiry, or null.
  final DateTime? endsAt;

  /// Made only for this customer (e.g. a referral reward).
  final bool isPersonal;

  /// The coupon's minimum order value (server amount), if any.
  final String? minOrderValue;

  final CouponDiscountType discountType;

  /// Why it was given, for a reward (`source`).
  final RewardSource source;

  /// A free-carton reward's size: the store's fixed free size, pre-filled
  /// by the server (ADR 0003), or the size chosen when it is on the cart.
  final int? freeVariantId;

  /// Free cartons this reward gives (`free_quantity`, ADR 0003); null for
  /// other coupons, or from a server before ADR 0003.
  final int? freeQuantity;

  /// A free-carton reward (`FREE_UNIT`).
  bool get isFreeCarton => discountType == CouponDiscountType.freeUnit;

  /// A free-carton reward the server applies without a size choice: the
  /// store has a fixed free size (ADR 0003). Otherwise applying it needs a
  /// size (the size sheet).
  bool get hasFixedFreeSize => isFreeCarton && freeVariantId != null;
}

/// The delivery-instruction chips (`DeliveryInstructionChipEnum`).
enum InstructionTag {
  dontRingBell('DONT_RING_BELL'),
  leaveAtDoor('LEAVE_AT_DOOR'),
  avoidCalling('AVOID_CALLING');

  const InstructionTag(this.wireValue);

  final String wireValue;
}

/// Chips plus free text (`DeliveryInstructions`). [tags] keeps the order
/// the chips were chosen in.
@immutable
class DeliveryInstructions {
  const DeliveryInstructions({this.tags = const {}, this.note = ''});

  static const none = DeliveryInstructions();

  /// `note` max length in the schema.
  static const maxNoteLength = 200;

  final Set<InstructionTag> tags;
  final String note;

  bool get isEmpty => tags.isEmpty && note.trim().isEmpty;

  DeliveryInstructions copyWith({Set<InstructionTag>? tags, String? note}) =>
      DeliveryInstructions(tags: tags ?? this.tags, note: note ?? this.note);

  @override
  bool operator ==(Object other) =>
      other is DeliveryInstructions &&
      setEquals(other.tags, tags) &&
      other.note == note;

  @override
  int get hashCode => Object.hash(Object.hashAllUnordered(tags), note);
}

/// `PATCH /cart/`: only the non-null fields change.
@immutable
class CartUpdate {
  const CartUpdate({this.tip, this.instructions, this.addressId});

  /// A decimal string; `"0.00"` removes the tip.
  final String? tip;
  final DeliveryInstructions? instructions;
  final int? addressId;
}

/// What the tile knew about a variant when it was added. Only the fake
/// backend uses it (the server knows the variant); the API repository
/// ignores it.
@immutable
class CartLinePreview {
  const CartLinePreview({required this.productName, required this.variant});

  factory CartLinePreview.of(CatalogVariant variant, String productName) =>
      CartLinePreview(productName: productName, variant: variant);

  final String productName;
  final CatalogVariant variant;
}
