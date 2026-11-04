// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/payment_method_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_create_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderCreateRequest {
  /// Returns a new [OrderCreateRequest] instance.
  OrderCreateRequest({
    required this.addressId,

    required this.paymentMethod,

    required this.expectedGrandTotal,
  });

  /// One of the caller's saved addresses, inside the service area of the store in `X-Store-Id`. Unknown or another user's: 400.
  // minimum: 1
  @JsonKey(name: r'address_id', required: true, includeIfNull: false)
  final int addressId;

  @JsonKey(
    name: r'payment_method',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PaymentMethodEnum.unknownDefaultOpenApi,
  )
  final PaymentMethodEnum paymentMethod;

  /// The cart's `bill.grand_total` exactly as displayed. If the server's bill differs (a price, fee or coupon changed), the order is not placed: 409 `PRICE_CHANGED`; reload the cart and show the new bill.
  @JsonKey(name: r'expected_grand_total', required: true, includeIfNull: false)
  final String expectedGrandTotal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderCreateRequest &&
          other.addressId == addressId &&
          other.paymentMethod == paymentMethod &&
          other.expectedGrandTotal == expectedGrandTotal;

  @override
  int get hashCode =>
      addressId.hashCode + paymentMethod.hashCode + expectedGrandTotal.hashCode;

  factory OrderCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$OrderCreateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OrderCreateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
