// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_store.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderStore {
  /// Returns a new [OrderStore] instance.
  OrderStore({required this.id, required this.name});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// e.g. \"Jivo Sector 14, Gurugram\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderStore && other.id == id && other.name == name;

  @override
  int get hashCode => id.hashCode + name.hashCode;

  factory OrderStore.fromJson(Map<String, dynamic> json) =>
      _$OrderStoreFromJson(json);

  Map<String, dynamic> toJson() => _$OrderStoreToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
