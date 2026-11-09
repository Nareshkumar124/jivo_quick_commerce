// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unread_count.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UnreadCount {
  /// Returns a new [UnreadCount] instance.
  UnreadCount({required this.unread});

  /// Unread inbox entries for this app.
  @JsonKey(name: r'unread', required: true, includeIfNull: false)
  final int unread;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is UnreadCount && other.unread == unread;

  @override
  int get hashCode => unread.hashCode;

  factory UnreadCount.fromJson(Map<String, dynamic> json) =>
      _$UnreadCountFromJson(json);

  Map<String, dynamic> toJson() => _$UnreadCountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
