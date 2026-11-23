// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/vehicle_type_enum.dart';
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

    required this.vehicleType,

    required this.lat,

    required this.lng,

    required this.heading,

    required this.updatedAt,

    required this.isStale,
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

  /// T-821: bike, scooter, ... (the vehicle number is never shown).  * `BICYCLE` - Bicycle * `E_BIKE` - E-bike * `MOTORBIKE` - Motorbike * `SCOOTER` - Scooter
  @JsonKey(
    name: r'vehicle_type',
    required: true,
    includeIfNull: true,
    unknownEnumValue: VehicleTypeEnum.unknownDefaultOpenApi,
  )
  final VehicleTypeEnum? vehicleType;

  /// Last known position; null if none.
  @JsonKey(name: r'lat', required: true, includeIfNull: true)
  final double? lat;

  @JsonKey(name: r'lng', required: true, includeIfNull: true)
  final double? lng;

  /// T-821: degrees from north (rotate the marker); null when unknown.
  @JsonKey(name: r'heading', required: true, includeIfNull: true)
  final double? heading;

  /// When that position was recorded.
  @JsonKey(name: r'updated_at', required: true, includeIfNull: true)
  final DateTime? updatedAt;

  /// T-821: true when there is no position or it is older than TRACKING_STALE_SECONDS (60 s): grey the marker out and show \"Last updated ... ago\".
  @JsonKey(name: r'is_stale', required: true, includeIfNull: false)
  final bool isStale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackRider &&
          other.name == name &&
          other.phone == phone &&
          other.photo == photo &&
          other.vehicleType == vehicleType &&
          other.lat == lat &&
          other.lng == lng &&
          other.heading == heading &&
          other.updatedAt == updatedAt &&
          other.isStale == isStale;

  @override
  int get hashCode =>
      name.hashCode +
      (phone == null ? 0 : phone.hashCode) +
      (photo == null ? 0 : photo.hashCode) +
      (vehicleType == null ? 0 : vehicleType.hashCode) +
      (lat == null ? 0 : lat.hashCode) +
      (lng == null ? 0 : lng.hashCode) +
      (heading == null ? 0 : heading.hashCode) +
      (updatedAt == null ? 0 : updatedAt.hashCode) +
      isStale.hashCode;

  factory TrackRider.fromJson(Map<String, dynamic> json) =>
      _$TrackRiderFromJson(json);

  Map<String, dynamic> toJson() => _$TrackRiderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
