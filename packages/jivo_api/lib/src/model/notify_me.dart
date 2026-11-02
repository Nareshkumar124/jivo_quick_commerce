// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notify_me.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NotifyMe {
  /// Returns a new [NotifyMe] instance.
  NotifyMe({
    required this.id,

    required this.lat,

    required this.lng,

    this.phone,

    this.addressText,

    required this.createdAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Latitude (WGS84, decimal degrees).
  // minimum: -90
  // maximum: 90
  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  /// Longitude (WGS84, decimal degrees).
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  /// Contact for the 'we now deliver here' message. Optional: defaults to the signed-in user's phone; anonymous requests without it are kept as a demand signal only.
  @JsonKey(name: r'phone', required: false, includeIfNull: false)
  final String? phone;

  /// The reverse-geocoded address shown on the map screen (for ops planning).
  @JsonKey(name: r'address_text', required: false, includeIfNull: false)
  final String? addressText;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotifyMe &&
          other.id == id &&
          other.lat == lat &&
          other.lng == lng &&
          other.phone == phone &&
          other.addressText == addressText &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      id.hashCode +
      lat.hashCode +
      lng.hashCode +
      (phone == null ? 0 : phone.hashCode) +
      addressText.hashCode +
      createdAt.hashCode;

  factory NotifyMe.fromJson(Map<String, dynamic> json) =>
      _$NotifyMeFromJson(json);

  Map<String, dynamic> toJson() => _$NotifyMeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
