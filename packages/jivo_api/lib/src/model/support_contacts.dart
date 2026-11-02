// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'support_contacts.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SupportContacts {
  /// Returns a new [SupportContacts] instance.
  SupportContacts({required this.phone, required this.email});

  /// Support phone, E.164.
  @JsonKey(name: r'phone', required: true, includeIfNull: false)
  final String phone;

  @JsonKey(name: r'email', required: true, includeIfNull: false)
  final String email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportContacts && other.phone == phone && other.email == email;

  @override
  int get hashCode => phone.hashCode + email.hashCode;

  factory SupportContacts.fromJson(Map<String, dynamic> json) =>
      _$SupportContactsFromJson(json);

  Map<String, dynamic> toJson() => _$SupportContactsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
