// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/checkout_blocker.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'checkout_status.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CheckoutStatus {
  /// Returns a new [CheckoutStatus] instance.
  CheckoutStatus({required this.canPlaceOrder, required this.blockers});

  /// Enable the checkout button only when true (no blockers).
  @JsonKey(name: r'can_place_order', required: true, includeIfNull: false)
  final bool canPlaceOrder;

  /// Everything that stops the order now, most important first.
  @JsonKey(name: r'blockers', required: true, includeIfNull: false)
  final List<CheckoutBlocker> blockers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutStatus &&
          other.canPlaceOrder == canPlaceOrder &&
          other.blockers == blockers;

  @override
  int get hashCode => canPlaceOrder.hashCode + blockers.hashCode;

  factory CheckoutStatus.fromJson(Map<String, dynamic> json) =>
      _$CheckoutStatusFromJson(json);

  Map<String, dynamic> toJson() => _$CheckoutStatusToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
