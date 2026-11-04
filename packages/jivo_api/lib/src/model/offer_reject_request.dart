// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/offer_reject_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'offer_reject_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OfferRejectRequest {
  /// Returns a new [OfferRejectRequest] instance.
  OfferRejectRequest({this.reason});

  @JsonKey(
    name: r'reason',
    required: false,
    includeIfNull: false,
    unknownEnumValue: OfferRejectReasonEnum.unknownDefaultOpenApi,
  )
  final OfferRejectReasonEnum? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfferRejectRequest && other.reason == reason;

  @override
  int get hashCode => (reason == null ? 0 : reason.hashCode);

  factory OfferRejectRequest.fromJson(Map<String, dynamic> json) =>
      _$OfferRejectRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OfferRejectRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
