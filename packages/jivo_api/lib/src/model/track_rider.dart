// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'track_rider.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TrackRider {
  /// Returns a new [TrackRider] instance.
  TrackRider({
    required this.name,

    required this.phone,

    required this.photo,

    required this.lat,

    required this.lng,

    required this.updatedAt,
  });

  /// The rider's first name and last initial.
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// E.164. Only while the order is OUT_FOR_DELIVERY (and only to the order's owner); null otherwise. Masked/proxy calling is planned.
  @JsonKey(name: r'phone', required: true, includeIfNull: true)
  final String? phone;

  /// Signed https link to the rider's photo, valid about an hour (re-read `track/` for a fresh one); null without a photo.
  @JsonKey(name: r'photo', required: true, includeIfNull: true)
  final String? photo;

  /// Last known position; null if none.
  @JsonKey(name: r'lat', required: true, includeIfNull: true)
  final double? lat;

  @JsonKey(name: r'lng', required: true, includeIfNull: true)
  final double? lng;

  /// When that position was recorded.
  @JsonKey(name: r'updated_at', required: true, includeIfNull: true)
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackRider &&
          other.name == name &&
          other.phone == phone &&
          other.photo == photo &&
          other.lat == lat &&
          other.lng == lng &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      name.hashCode +
      (phone == null ? 0 : phone.hashCode) +
      (photo == null ? 0 : photo.hashCode) +
      (lat == null ? 0 : lat.hashCode) +
      (lng == null ? 0 : lng.hashCode) +
      (updatedAt == null ? 0 : updatedAt.hashCode);

  factory TrackRider.fromJson(Map<String, dynamic> json) =>
      _$TrackRiderFromJson(json);

  Map<String, dynamic> toJson() => _$TrackRiderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
