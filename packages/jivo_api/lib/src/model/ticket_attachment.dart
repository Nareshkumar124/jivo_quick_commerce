// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ticket_attachment.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TicketAttachment {
  /// Returns a new [TicketAttachment] instance.
  TicketAttachment({required this.key, required this.url});

  @JsonKey(name: r'key', required: true, includeIfNull: false)
  final String key;

  @JsonKey(name: r'url', required: true, includeIfNull: false)
  final String url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketAttachment && other.key == key && other.url == url;

  @override
  int get hashCode => key.hashCode + url.hashCode;

  factory TicketAttachment.fromJson(Map<String, dynamic> json) =>
      _$TicketAttachmentFromJson(json);

  Map<String, dynamic> toJson() => _$TicketAttachmentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
