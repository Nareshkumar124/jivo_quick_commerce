// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'delivery_otp_state.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeliveryOtpState {
  /// Returns a new [DeliveryOtpState] instance.
  DeliveryOtpState({
    required this.length,

    required this.attemptsRemaining,

    required this.locked,
  });

  /// Digits of the customer's delivery OTP (4).
  @JsonKey(name: r'length', required: true, includeIfNull: false)
  final int length;

  /// Of 5.
  @JsonKey(name: r'attempts_remaining', required: true, includeIfNull: false)
  final int attemptsRemaining;

  /// True after 5 wrong OTPs: ops are alerted; call support.
  @JsonKey(name: r'locked', required: true, includeIfNull: false)
  final bool locked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryOtpState &&
          other.length == length &&
          other.attemptsRemaining == attemptsRemaining &&
          other.locked == locked;

  @override
  int get hashCode =>
      length.hashCode + attemptsRemaining.hashCode + locked.hashCode;

  factory DeliveryOtpState.fromJson(Map<String, dynamic> json) =>
      _$DeliveryOtpStateFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryOtpStateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
