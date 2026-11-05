// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ticket_reply_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TicketReplyRequest {
  /// Returns a new [TicketReplyRequest] instance.
  TicketReplyRequest({required this.message});

  /// Plain text, 1 to 1000 characters after trimming.
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketReplyRequest && other.message == message;

  @override
  int get hashCode => message.hashCode;

  factory TicketReplyRequest.fromJson(Map<String, dynamic> json) =>
      _$TicketReplyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TicketReplyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
