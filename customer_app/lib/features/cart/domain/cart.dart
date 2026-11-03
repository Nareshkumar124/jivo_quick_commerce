import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog_models.dart';

/// The cart as the server reports it (`03 §2.8`, `06 §2.5`).
///
/// Money is never computed in the app (`08 §6`). Every amount here is the
/// server's decimal string (`"249.00"`), shown only with `formatRupees`.
/// Totals, discounts, fees, savings and the free-delivery and minimum-order
/// gaps all come from the server; when a field is missing the screen hides
/// it rather than deriving it.
///
/// TODO(api): field names follow `06 §2.5` and `08 §6.2` until the Phase 3
/// contract (`backend/openapi/schema.yaml`) is published. The API repository
/// maps the generated `jivo_api` models into these types at S3-A.
@immutable
class CartSnapshot {
  const CartSnapshot({
    this.quantities = const {},
    this.itemCount = 0,
    this.itemTotal,
    this.lines = const [],
    this.bill,
    this.coupon,
    this.instructions = DeliveryInstructions.none,
    this.addressId,
    this.minimumOrder,
    this.codAvailable = false,
  });

  /// A snapshot built from the server's lines: [quantities] and
  /// [itemCount] are read from them (unit counts, not money).
  factory CartSnapshot.fromLines({
    required List<CartLine> lines,
    CartBill? bill,
    AppliedCoupon? coupon,
    DeliveryInstructions instructions = DeliveryInstructions.none,
    int? addressId,
    MinimumOrder? minimumOrder,
    bool codAvailable = false,
    int? itemCount,
  }) => CartSnapshot(
    quantities: Map.unmodifiable({
      for (final line in lines) line.variantId: line.quantity,
    }),
    itemCount: itemCount ?? lines.fold(0, (sum, line) => sum + line.quantity),
    itemTotal: bill?.itemTotal,
    lines: List.unmodifiable(lines),
    bill: bill,
    coupon: coupon,
    instructions: instructions,
    addressId: addressId,
    minimumOrder: minimumOrder,
    codAvailable: codAvailable,
  );

  static const empty = CartSnapshot();

  /// Quantity per variant id.
  final Map<int, int> quantities;

  /// Units in the cart, as the server counts them.
  final int itemCount;

  /// The server's item total (the cart bar amount), or null when not known.
  final String? itemTotal;

  /// The cart lines, in the server's order.
  final List<CartLine> lines;

  /// The bill from the pricing engine; null for an empty cart.
  final CartBill? bill;

  /// The applied coupon, if any.
  final AppliedCoupon? coupon;

  /// What the customer asked the delivery partner to do.
  final DeliveryInstructions instructions;

  /// The address the bill was computed for (`GET /cart/?address_id=`).
  final int? addressId;

  /// Whether the cart meets the store's minimum order. Null when the server
  /// did not say; checkout then relies on the server's `MIN_ORDER_NOT_MET`.
  final MinimumOrder? minimumOrder;

  /// Whether Cash on Delivery may be offered for this cart (`03 §2.9`:
  /// "shown only if eligible"). TODO(api): not in `06 §2.5` yet.
  final bool codAvailable;

  bool get isEmpty => itemCount == 0;

  int quantityOf(int variantId) => quantities[variantId] ?? 0;

  /// The line for [variantId], or null.
  CartLine? lineFor(int variantId) {
    for (final line in lines) {
      if (line.variantId == variantId) return line;
    }
    return null;
  }

  /// Lines the server flagged as unavailable or reduced (`03 §2.8`, stock
  /// re-validation). Checkout stays disabled until they are fixed.
  List<CartLine> get problemLines =>
      lines.where((line) => line.issue != CartLineIssue.none).toList();

  bool get hasProblems => lines.any((line) => line.issue != CartLineIssue.none);
}

/// A stock problem on a cart line (`03 §2.8`).
enum CartLineIssue {
  none,

  /// Fewer units are available than in the cart: [CartLine.availableQuantity].
  reduced,

  /// None available.
  unavailable,
}

/// One cart line (`06 §2.5`).
@immutable
class CartLine {
  const CartLine({
    required this.id,
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.sellingPrice,
    required this.mrp,
    required this.quantity,
    required this.lineTotal,
    required this.orderableQuantity,
    this.productSlug,
    this.imageUrl,
    this.issue = CartLineIssue.none,
    this.availableQuantity,
  });

  /// The server's line id: `PATCH`/`DELETE /cart/items/{id}/`.
  final int id;
  final int variantId;
  final String? productSlug;
  final String productName;

  /// e.g. "1 L".
  final String variantName;
  final String? imageUrl;

  /// Unit price and MRP at this store.
  final String sellingPrice;
  final String mrp;
  final int quantity;

  /// The server's `selling_price × quantity`.
  final String lineTotal;

  /// The stepper cap: the server's `min(stock, max_qty_per_order)`.
  final int orderableQuantity;
  final CartLineIssue issue;

  /// Units available now, set when [issue] is [CartLineIssue.reduced].
  final int? availableQuantity;
}

/// The bill from `cart.services.compute_bill` (`08 §6.2`), as sent.
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
    this.totalSavings,
    this.freeDeliveryShortfall,
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

  /// "You save ₹X" (`03 §2.8`). TODO(api): needs a server field; the app
  /// does not add the discounts up. Hidden when null.
  final String? totalSavings;

  /// "Add ₹X more for free delivery" (`03 §2.8`). TODO(api): needs a server
  /// field; the app does not subtract from the threshold. Hidden when null
  /// or zero.
  final String? freeDeliveryShortfall;
}

/// The store's minimum order for this cart (`03 §2.8`), as the server
/// judged it.
@immutable
class MinimumOrder {
  const MinimumOrder({required this.met, required this.amount, this.shortfall});

  final bool met;

  /// The minimum item total.
  final String amount;

  /// How much more to add, when not [met].
  final String? shortfall;
}

/// The coupon on the cart.
@immutable
class AppliedCoupon {
  const AppliedCoupon({
    required this.code,
    required this.discount,
    this.title,
    this.problem,
  });

  final String code;

  /// The server's coupon discount on this cart.
  final String discount;
  final String? title;

  /// Set when the coupon no longer applies (e.g. the cart dropped below its
  /// minimum); [discount] is then zero. TODO(api): confirm the server keeps
  /// the coupon and flags it rather than removing it.
  final CouponProblem? problem;
}

/// Why a coupon can't be used (`03 §2.8`: "clear error reasons").
enum CouponProblem {
  minOrderNotMet('MIN_ORDER_NOT_MET'),
  expired('EXPIRED'),
  usageExceeded('USAGE_EXCEEDED'),
  notEligible('NOT_ELIGIBLE');

  const CouponProblem(this.wireValue);

  final String wireValue;

  static CouponProblem fromWire(String? value) => values.firstWhere(
    (problem) => problem.wireValue == value,
    orElse: () => notEligible,
  );
}

/// One coupon in the coupon sheet (`GET /cart/coupons/`).
@immutable
class CouponOffer {
  const CouponOffer({
    required this.code,
    required this.title,
    this.description,
    this.savings,
    this.problem,
    this.shortfall,
  });

  final String code;
  final String title;
  final String? description;

  /// What it saves on this cart, when eligible.
  final String? savings;

  /// Why it can't be applied; null when eligible.
  final CouponProblem? problem;

  /// "Add ₹X more", for [CouponProblem.minOrderNotMet].
  final String? shortfall;

  bool get eligible => problem == null;
}

/// The delivery-instruction chips (`03 §2.8`).
enum InstructionTag {
  dontRingBell('DONT_RING_BELL'),
  leaveAtDoor('LEAVE_AT_DOOR'),
  avoidCalling('AVOID_CALLING');

  const InstructionTag(this.wireValue);

  /// TODO(api): the wire format of `instructions` is not in `06 §2.5`.
  final String wireValue;
}

/// Chips plus free text.
@immutable
class DeliveryInstructions {
  const DeliveryInstructions({this.tags = const {}, this.note = ''});

  static const none = DeliveryInstructions();

  /// Longest free-text note the app accepts. TODO(api): confirm the limit.
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
/// cart uses it (TODO(api)): the server already knows the variant, and the
/// API repository ignores it.
@immutable
class CartLinePreview {
  const CartLinePreview({
    required this.productName,
    required this.variantName,
    required this.sellingPrice,
    required this.mrp,
    required this.orderableQuantity,
    this.imageUrl,
  });

  factory CartLinePreview.of(CatalogVariant variant, String productName) =>
      CartLinePreview(
        productName: productName,
        variantName: variant.name,
        sellingPrice: variant.sellingPrice,
        mrp: variant.mrp,
        orderableQuantity: variant.maxSelectable,
        imageUrl: variant.imageUrl,
      );

  final String productName;
  final String variantName;
  final String sellingPrice;
  final String mrp;
  final int orderableQuantity;
  final String? imageUrl;
}
