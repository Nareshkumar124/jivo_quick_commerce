// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_rider_status_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsRiderStatusData {
  /// Returns a new [WsRiderStatusData] instance.
  WsRiderStatusData({
    required this.riderId,

    required this.storeId,

    required this.isOnline,

    required this.onTask,

    required this.updatedAt,
  });

  @JsonKey(name: r'rider_id', required: true, includeIfNull: false)
  final int riderId;

  @JsonKey(name: r'store_id', required: true, includeIfNull: false)
  final int storeId;

  @JsonKey(name: r'is_online', required: true, includeIfNull: false)
  final bool isOnline;

  @JsonKey(name: r'on_task', required: true, includeIfNull: false)
  final bool onTask;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsRiderStatusData &&
          other.riderId == riderId &&
          other.storeId == storeId &&
          other.isOnline == isOnline &&
          other.onTask == onTask &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      riderId.hashCode +
      storeId.hashCode +
      isOnline.hashCode +
      onTask.hashCode +
      updatedAt.hashCode;

  factory WsRiderStatusData.fromJson(Map<String, dynamic> json) =>
      _$WsRiderStatusDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsRiderStatusDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
