// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_store.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'store_list.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class StoreList {
  /// Returns a new [StoreList] instance.
  StoreList({required this.results});

  @JsonKey(name: r'results', required: true, includeIfNull: false)
  final List<RiderStore> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoreList && other.results == results;

  @override
  int get hashCode => results.hashCode;

  factory StoreList.fromJson(Map<String, dynamic> json) =>
      _$StoreListFromJson(json);

  Map<String, dynamic> toJson() => _$StoreListToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
