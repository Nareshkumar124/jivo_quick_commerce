// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/applied_coupon.dart';
import 'package:jivo_api/src/model/checkout_status.dart';
import 'package:jivo_api/src/model/store_status.dart';
import 'package:jivo_api/src/model/delivery_instructions.dart';
import 'package:jivo_api/src/model/cart_line.dart';
import 'package:jivo_api/src/model/cart_thresholds.dart';
import 'package:jivo_api/src/model/address.dart';
import 'package:jivo_api/src/model/payment_option.dart';
import 'package:jivo_api/src/model/bill.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cart.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Cart {
  /// Returns a new [Cart] instance.
  Cart({
    required this.store,

    required this.items,

    required this.itemCount,

    required this.coupon,

    required this.tip,

    required this.instructions,

    required this.address,

    required this.bill,

    required this.thresholds,

    required this.paymentMethods,

    required this.checkout,
  });

  /// The store pricing this cart, and whether it is open.
  @JsonKey(name: r'store', required: true, includeIfNull: false)
  final StoreStatus store;

  /// Lines in the order they were added.
  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<CartLine> items;

  /// Units in the cart (sum of quantities), for the cart badge.
  // minimum: 0
  @JsonKey(name: r'item_count', required: true, includeIfNull: false)
  final int itemCount;

  /// Null when no coupon is applied.
  @JsonKey(name: r'coupon', required: true, includeIfNull: true)
  final AppliedCoupon? coupon;

  /// The chosen rider tip (kept while the cart is empty; billed only with items).
  @JsonKey(name: r'tip', required: true, includeIfNull: false)
  final String tip;

  @JsonKey(name: r'instructions', required: true, includeIfNull: false)
  final DeliveryInstructions instructions;

  /// The delivery address the cart is checked against: `?address_id=` when sent, else the one saved with `PATCH /cart/`. Null when none is selected.
  @JsonKey(name: r'address', required: true, includeIfNull: true)
  final Address? address;

  @JsonKey(name: r'bill', required: true, includeIfNull: false)
  final Bill bill;

  @JsonKey(name: r'thresholds', required: true, includeIfNull: false)
  final CartThresholds thresholds;

  /// ONLINE then COD, each with its availability for this cart.
  @JsonKey(name: r'payment_methods', required: true, includeIfNull: false)
  final List<PaymentOption> paymentMethods;

  @JsonKey(name: r'checkout', required: true, includeIfNull: false)
  final CheckoutStatus checkout;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cart &&
          other.store == store &&
          other.items == items &&
          other.itemCount == itemCount &&
          other.coupon == coupon &&
          other.tip == tip &&
          other.instructions == instructions &&
          other.address == address &&
          other.bill == bill &&
          other.thresholds == thresholds &&
          other.paymentMethods == paymentMethods &&
          other.checkout == checkout;

  @override
  int get hashCode =>
      store.hashCode +
      items.hashCode +
      itemCount.hashCode +
      (coupon == null ? 0 : coupon.hashCode) +
      tip.hashCode +
      instructions.hashCode +
      (address == null ? 0 : address.hashCode) +
      bill.hashCode +
      thresholds.hashCode +
      paymentMethods.hashCode +
      checkout.hashCode;

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);

  Map<String, dynamic> toJson() => _$CartToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
