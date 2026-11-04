// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order.dart';
import 'package:jivo_api/src/model/razorpay_checkout.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_placement.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderPlacement {
  /// Returns a new [OrderPlacement] instance.
  OrderPlacement({required this.order, required this.razorpay});

  @JsonKey(name: r'order', required: true, includeIfNull: false)
  final Order order;

  /// ONLINE orders in PAYMENT_PENDING: open checkout with it, then call `POST /payments/razorpay/verify/`. Null for COD (and for an online order that is no longer awaiting payment).
  @JsonKey(name: r'razorpay', required: true, includeIfNull: true)
  final RazorpayCheckout? razorpay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderPlacement &&
          other.order == order &&
          other.razorpay == razorpay;

  @override
  int get hashCode =>
      order.hashCode + (razorpay == null ? 0 : razorpay.hashCode);

  factory OrderPlacement.fromJson(Map<String, dynamic> json) =>
      _$OrderPlacementFromJson(json);

  Map<String, dynamic> toJson() => _$OrderPlacementToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
