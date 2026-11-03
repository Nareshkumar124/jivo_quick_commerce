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
  });

  /// A snapshot built from the server's lines: [quantities] is read from
  /// them (unit counts, not money).
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

  bool get isEmpty => itemCount == 0;

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

  /// Whether the server offers [method] for this cart.
  bool offers(PaymentMethod method) => paymentOptions.any(
    (option) => option.method == method && option.available,
  );

  /// Cash on Delivery is shown only when eligible (`03 §2.9`).
  bool get codAvailable => offers(PaymentMethod.cod);
}

/// `CartLineIssueCodeEnum`.
enum CartIssueCode {
  /// Nothing can be ordered: remove the line.
  outOfStock,

  /// Fewer units can be ordered: reduce to `variant.orderable_quantity`.
  quantityUnavailable,

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
  });

  /// The server's line id.
  final int id;
  final int? productId;
  final String? productSlug;
  final String productName;

  /// The variant with its current price and stock (`VariantSummary`).
  final CatalogVariant variant;
  final int quantity;

  /// The server's `mrp × quantity` and `selling_price × quantity`.
  final String lineMrpTotal;
  final String lineTotal;

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

  /// "You save ₹X": the server's product + coupon discount.
  final String totalSavings;
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
  });

  final String minOrderValue;

  /// Item value still needed for the minimum; null when reached.
  final String? amountToMinOrder;
  final String? freeDeliveryThreshold;

  /// For "Add ₹X more for FREE delivery"; null when delivery is free.
  final String? amountToFreeDelivery;
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
  storeClosed,
  stockUnavailable,
  minOrderNotMet,
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

/// The coupon on the cart (`AppliedCoupon`).
@immutable
class AppliedCoupon {
  const AppliedCoupon({
    required this.code,
    required this.title,
    required this.discount,
    this.isApplicable = true,
    this.message,
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
