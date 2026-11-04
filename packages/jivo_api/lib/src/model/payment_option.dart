// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/payment_method_enum.dart';
import 'package:jivo_api/src/model/payment_unavailable_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_option.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PaymentOption {
  /// Returns a new [PaymentOption] instance.
  PaymentOption({
    required this.method,

    required this.isAvailable,

    required this.unavailableReason,

    required this.message,
  });

  @JsonKey(
    name: r'method',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PaymentMethodEnum.unknownDefaultOpenApi,
  )
  final PaymentMethodEnum method;

  /// Show the method only when true (03 §2.9: COD is shown only if eligible).
  @JsonKey(name: r'is_available', required: true, includeIfNull: false)
  final bool isAvailable;

  @JsonKey(
    name: r'unavailable_reason',
    required: true,
    includeIfNull: true,
    unknownEnumValue: PaymentUnavailableReasonEnum.unknownDefaultOpenApi,
  )
  final PaymentUnavailableReasonEnum? unavailableReason;

  /// Display text when not available; null when available.
  @JsonKey(name: r'message', required: true, includeIfNull: true)
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentOption &&
          other.method == method &&
          other.isAvailable == isAvailable &&
          other.unavailableReason == unavailableReason &&
          other.message == message;

  @override
  int get hashCode =>
      method.hashCode +
      isAvailable.hashCode +
      (unavailableReason == null ? 0 : unavailableReason.hashCode) +
      (message == null ? 0 : message.hashCode);

  factory PaymentOption.fromJson(Map<String, dynamic> json) =>
      _$PaymentOptionFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentOptionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
