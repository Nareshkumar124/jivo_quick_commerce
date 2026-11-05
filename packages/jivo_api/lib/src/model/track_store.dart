// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'track_store.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TrackStore {
  /// Returns a new [TrackStore] instance.
  TrackStore({
    required this.id,

    required this.name,

    required this.lat,

    required this.lng,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackStore &&
          other.id == id &&
          other.name == name &&
          other.lat == lat &&
          other.lng == lng;

  @override
  int get hashCode => id.hashCode + name.hashCode + lat.hashCode + lng.hashCode;

  factory TrackStore.fromJson(Map<String, dynamic> json) =>
      _$TrackStoreFromJson(json);

  Map<String, dynamic> toJson() => _$TrackStoreToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
