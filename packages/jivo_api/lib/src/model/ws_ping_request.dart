// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_ping_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsPingRequest {
  /// Returns a new [WsPingRequest] instance.
  WsPingRequest({required this.type});

  /// \"ping\"
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WsPingRequest && other.type == type;

  @override
  int get hashCode => type.hashCode;

  factory WsPingRequest.fromJson(Map<String, dynamic> json) =>
      _$WsPingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WsPingRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
