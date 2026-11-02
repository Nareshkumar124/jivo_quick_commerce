// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'account_deletion.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AccountDeletion {
  /// Returns a new [AccountDeletion] instance.
  AccountDeletion({required this.deletedAt, required this.anonymiseAfter});

  /// When the deletion was recorded.
  @JsonKey(name: r'deleted_at', required: true, includeIfNull: false)
  final DateTime deletedAt;

  /// Personal data is anonymised after this time (30-day grace period, 07 §4).
  @JsonKey(name: r'anonymise_after', required: true, includeIfNull: false)
  final DateTime anonymiseAfter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountDeletion &&
          other.deletedAt == deletedAt &&
          other.anonymiseAfter == anonymiseAfter;

  @override
  int get hashCode => deletedAt.hashCode + anonymiseAfter.hashCode;

  factory AccountDeletion.fromJson(Map<String, dynamic> json) =>
      _$AccountDeletionFromJson(json);

  Map<String, dynamic> toJson() => _$AccountDeletionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
