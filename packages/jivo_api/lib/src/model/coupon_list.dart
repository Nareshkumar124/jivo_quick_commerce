// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/coupon_offer.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coupon_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CouponList {
  /// Returns a new [CouponList] instance.
  CouponList({required this.results});

  /// Visible coupons valid at this store now, eligible first (highest savings first), then the rest. Expired, used-up and other-store coupons are not listed. Not paginated.
  @JsonKey(name: r'results', required: true, includeIfNull: false)
  final List<CouponOffer> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CouponList && other.results == results;

  @override
  int get hashCode => results.hashCode;

  factory CouponList.fromJson(Map<String, dynamic> json) =>
      _$CouponListFromJson(json);

  Map<String, dynamic> toJson() => _$CouponListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
