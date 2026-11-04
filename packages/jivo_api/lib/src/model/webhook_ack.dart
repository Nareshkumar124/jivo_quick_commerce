// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/webhook_result_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webhook_ack.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebhookAck {
  /// Returns a new [WebhookAck] instance.
  WebhookAck({required this.status});

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WebhookResultEnum.unknownDefaultOpenApi,
  )
  final WebhookResultEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WebhookAck && other.status == status;

  @override
  int get hashCode => status.hashCode;

  factory WebhookAck.fromJson(Map<String, dynamic> json) =>
      _$WebhookAckFromJson(json);

  Map<String, dynamic> toJson() => _$WebhookAckToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
