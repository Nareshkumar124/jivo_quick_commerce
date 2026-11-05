// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_store.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderStore {
  /// Returns a new [RiderStore] instance.
  RiderStore({required this.id, required this.name, required this.city});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// e.g. \"Jivo Sector 14\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'city', required: true, includeIfNull: false)
  final String city;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderStore &&
          other.id == id &&
          other.name == name &&
          other.city == city;

  @override
  int get hashCode => id.hashCode + name.hashCode + city.hashCode;

  factory RiderStore.fromJson(Map<String, dynamic> json) =>
      _$RiderStoreFromJson(json);

  Map<String, dynamic> toJson() => _$RiderStoreToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
