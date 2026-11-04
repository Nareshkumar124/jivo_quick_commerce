// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_verify_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaymentVerifyRequest {
  /// Returns a new [PaymentVerifyRequest] instance.
  PaymentVerifyRequest({
    required this.orderId,

    required this.razorpayOrderId,

    required this.razorpayPaymentId,

    required this.razorpaySignature,
  });

  /// Our order id (`Order.id`).
  // minimum: 1
  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  /// From the checkout success callback.
  @JsonKey(name: r'razorpay_order_id', required: true, includeIfNull: false)
  final String razorpayOrderId;

  /// From the checkout success callback.
  @JsonKey(name: r'razorpay_payment_id', required: true, includeIfNull: false)
  final String razorpayPaymentId;

  /// From the checkout success callback (64 hex characters).
  @JsonKey(name: r'razorpay_signature', required: true, includeIfNull: false)
  final String razorpaySignature;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentVerifyRequest &&
          other.orderId == orderId &&
          other.razorpayOrderId == razorpayOrderId &&
          other.razorpayPaymentId == razorpayPaymentId &&
          other.razorpaySignature == razorpaySignature;

  @override
  int get hashCode =>
      orderId.hashCode +
      razorpayOrderId.hashCode +
      razorpayPaymentId.hashCode +
      razorpaySignature.hashCode;

  factory PaymentVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$PaymentVerifyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentVerifyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
