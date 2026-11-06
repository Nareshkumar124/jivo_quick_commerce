// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_order_eta_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOrderEtaData {
  /// Returns a new [WsOrderEtaData] instance.
  WsOrderEtaData({
    required this.orderId,

    required this.etaAt,

    required this.etaMinutes,
  });

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  @JsonKey(name: r'eta_at', required: true, includeIfNull: false)
  final DateTime etaAt;

  /// Minutes from `sent_at`, at least 1.
  @JsonKey(name: r'eta_minutes', required: true, includeIfNull: false)
  final int etaMinutes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOrderEtaData &&
          other.orderId == orderId &&
          other.etaAt == etaAt &&
          other.etaMinutes == etaMinutes;

  @override
  int get hashCode => orderId.hashCode + etaAt.hashCode + etaMinutes.hashCode;

  factory WsOrderEtaData.fromJson(Map<String, dynamic> json) =>
      _$WsOrderEtaDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsOrderEtaDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
