// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coupon_apply_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CouponApplyRequest {
  /// Returns a new [CouponApplyRequest] instance.
  CouponApplyRequest({required this.code});

  /// Coupon code as typed; case-insensitive.
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CouponApplyRequest && other.code == code;

  @override
  int get hashCode => code.hashCode;

  factory CouponApplyRequest.fromJson(Map<String, dynamic> json) =>
      _$CouponApplyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CouponApplyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
