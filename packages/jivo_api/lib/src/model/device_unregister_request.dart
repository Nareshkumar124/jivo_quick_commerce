// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'device_unregister_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeviceUnregisterRequest {
  /// Returns a new [DeviceUnregisterRequest] instance.
  DeviceUnregisterRequest({required this.fcmToken});

  /// The token to stop pushing to.
  @JsonKey(name: r'fcm_token', required: true, includeIfNull: false)
  final String fcmToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceUnregisterRequest && other.fcmToken == fcmToken;

  @override
  int get hashCode => fcmToken.hashCode;

  factory DeviceUnregisterRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceUnregisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceUnregisterRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
