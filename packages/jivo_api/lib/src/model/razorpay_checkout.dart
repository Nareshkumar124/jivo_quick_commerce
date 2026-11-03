// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/razorpay_prefill.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'razorpay_checkout.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RazorpayCheckout {
  /// Returns a new [RazorpayCheckout] instance.
  RazorpayCheckout({
    required this.keyId,

    required this.orderId,

    required this.amount,

    required this.currency,

    required this.name,

    required this.description,

    required this.prefill,

    required this.expiresAt,

    required this.timeoutSeconds,
  });

  /// Razorpay key id (`key`). Local development only: `rzp_fake_jivo_local` means the server uses the fake gateway; complete the payment with the dev-only scheme in 06 §2.6 instead of opening Razorpay.
  @JsonKey(name: r'key_id', required: true, includeIfNull: false)
  final String keyId;

  /// Razorpay order id (`order_id`), \"order_...\".
  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final String orderId;

  /// `grand_total` in paise (`amount`), e.g. 75300 for ₹753.00. Display the order's `bill.grand_total` instead.
  // minimum: 100
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final int amount;

  /// Always \"INR\".
  @JsonKey(name: r'currency', required: true, includeIfNull: false)
  final String currency;

  /// Merchant name shown in checkout (`name`), \"Jivo\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// `description`, e.g. the order number.
  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(name: r'prefill', required: true, includeIfNull: false)
  final RazorpayPrefill prefill;

  /// Same as the order's `payment_expires_at`.
  @JsonKey(name: r'expires_at', required: true, includeIfNull: false)
  final DateTime expiresAt;

  /// Seconds left in the payment window (`timeout`), so checkout closes in time.
  // minimum: 1
  @JsonKey(name: r'timeout_seconds', required: true, includeIfNull: false)
  final int timeoutSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RazorpayCheckout &&
          other.keyId == keyId &&
          other.orderId == orderId &&
          other.amount == amount &&
          other.currency == currency &&
          other.name == name &&
          other.description == description &&
          other.prefill == prefill &&
          other.expiresAt == expiresAt &&
          other.timeoutSeconds == timeoutSeconds;

  @override
  int get hashCode =>
      keyId.hashCode +
      orderId.hashCode +
      amount.hashCode +
      currency.hashCode +
      name.hashCode +
      description.hashCode +
      prefill.hashCode +
      expiresAt.hashCode +
      timeoutSeconds.hashCode;

  factory RazorpayCheckout.fromJson(Map<String, dynamic> json) =>
      _$RazorpayCheckoutFromJson(json);

  Map<String, dynamic> toJson() => _$RazorpayCheckoutToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
