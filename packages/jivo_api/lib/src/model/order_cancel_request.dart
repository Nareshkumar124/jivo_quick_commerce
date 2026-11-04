// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cancel_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_cancel_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderCancelRequest {
  /// Returns a new [OrderCancelRequest] instance.
  OrderCancelRequest({required this.reason, this.note});

  @JsonKey(
    name: r'reason',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CancelReasonEnum.unknownDefaultOpenApi,
  )
  final CancelReasonEnum reason;

  /// Optional free text, e.g. for OTHER.
  @JsonKey(name: r'note', required: false, includeIfNull: false)
  final String? note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderCancelRequest &&
          other.reason == reason &&
          other.note == note;

  @override
  int get hashCode => reason.hashCode + note.hashCode;

  factory OrderCancelRequest.fromJson(Map<String, dynamic> json) =>
      _$OrderCancelRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OrderCancelRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
