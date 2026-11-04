// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bill.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Bill {
  /// Returns a new [Bill] instance.
  Bill({
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

  /// Sum of MRP x quantity. The struck-out 'Item total (MRP)'.
  @JsonKey(name: r'mrp_total', required: true, includeIfNull: false)
  final String mrpTotal;

  /// Sum of the store selling price x quantity (store price override applied).
  @JsonKey(name: r'item_total', required: true, includeIfNull: false)
  final String itemTotal;

  /// `mrp_total` - `item_total`.
  @JsonKey(name: r'product_discount', required: true, includeIfNull: false)
  final String productDiscount;

  /// Discount of the applied coupon, capped by its `max_discount` and by `item_total`. \"0.00\" without a coupon or when the coupon does not apply.
  @JsonKey(name: r'coupon_discount', required: true, includeIfNull: false)
  final String couponDiscount;

  /// Store delivery fee, \"0.00\" when `item_total` >= the free-delivery threshold: show \"FREE\" when \"0.00\".
  @JsonKey(name: r'delivery_fee', required: true, includeIfNull: false)
  final String deliveryFee;

  /// Charged when `item_total` is below the store's small-cart threshold, else \"0.00\".
  @JsonKey(name: r'small_cart_fee', required: true, includeIfNull: false)
  final String smallCartFee;

  /// Store handling fee (\"0.00\" by default).
  @JsonKey(name: r'handling_fee', required: true, includeIfNull: false)
  final String handlingFee;

  /// Rider tip chosen by the customer (\"0.00\" when none). Goes fully to the rider.
  @JsonKey(name: r'tip', required: true, includeIfNull: false)
  final String tip;

  /// **To pay.** Not rounded to the rupee in v1.
  @JsonKey(name: r'grand_total', required: true, includeIfNull: false)
  final String grandTotal;

  /// `product_discount` + `coupon_discount`: the highlighted 'You save' amount.
  @JsonKey(name: r'total_savings', required: true, includeIfNull: false)
  final String totalSavings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bill &&
          other.mrpTotal == mrpTotal &&
          other.itemTotal == itemTotal &&
          other.productDiscount == productDiscount &&
          other.couponDiscount == couponDiscount &&
          other.deliveryFee == deliveryFee &&
          other.smallCartFee == smallCartFee &&
          other.handlingFee == handlingFee &&
          other.tip == tip &&
          other.grandTotal == grandTotal &&
          other.totalSavings == totalSavings;

  @override
  int get hashCode =>
      mrpTotal.hashCode +
      itemTotal.hashCode +
      productDiscount.hashCode +
      couponDiscount.hashCode +
      deliveryFee.hashCode +
      smallCartFee.hashCode +
      handlingFee.hashCode +
      tip.hashCode +
      grandTotal.hashCode +
      totalSavings.hashCode;

  factory Bill.fromJson(Map<String, dynamic> json) => _$BillFromJson(json);

  Map<String, dynamic> toJson() => _$BillToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
