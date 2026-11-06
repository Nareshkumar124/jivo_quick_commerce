// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pickup_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PickupRequest {
  /// Returns a new [PickupRequest] instance.
  PickupRequest({required this.orderCode});

  /// The 4-character order code typed by the rider (ASCII letters and digits), or the whole bag QR payload `JQC1:<order_number>:<code>` as scanned. Case-insensitive. Anything else (non-ASCII, wrong shape): 400 `PICKUP_CODE_INVALID`.
  @JsonKey(name: r'order_code', required: true, includeIfNull: false)
  final String orderCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PickupRequest && other.orderCode == orderCode;

  @override
  int get hashCode => orderCode.hashCode;

  factory PickupRequest.fromJson(Map<String, dynamic> json) =>
      _$PickupRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PickupRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
