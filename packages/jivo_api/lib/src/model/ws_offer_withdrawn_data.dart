// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_offer_withdrawn_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOfferWithdrawnData {
  /// Returns a new [WsOfferWithdrawnData] instance.
  WsOfferWithdrawnData({
    required this.offerId,

    required this.taskId,

    required this.reason,
  });

  @JsonKey(name: r'offer_id', required: true, includeIfNull: false)
  final int offerId;

  @JsonKey(name: r'task_id', required: true, includeIfNull: false)
  final int taskId;

  @JsonKey(
    name: r'reason',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WsOfferWithdrawnDataReasonEnum.unknownDefaultOpenApi,
  )
  final WsOfferWithdrawnDataReasonEnum reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOfferWithdrawnData &&
          other.offerId == offerId &&
          other.taskId == taskId &&
          other.reason == reason;

  @override
  int get hashCode => offerId.hashCode + taskId.hashCode + reason.hashCode;

  factory WsOfferWithdrawnData.fromJson(Map<String, dynamic> json) =>
      _$WsOfferWithdrawnDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsOfferWithdrawnDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WsOfferWithdrawnDataReasonEnum {
  @JsonValue(r'EXPIRED')
  EXPIRED(r'EXPIRED'),
  @JsonValue(r'TAKEN')
  TAKEN(r'TAKEN'),
  @JsonValue(r'ORDER_CANCELLED')
  ORDER_CANCELLED(r'ORDER_CANCELLED'),
  @JsonValue(r'REASSIGNED')
  REASSIGNED(r'REASSIGNED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsOfferWithdrawnDataReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
