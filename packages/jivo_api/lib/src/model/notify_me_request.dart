// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notify_me_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NotifyMeRequest {
  /// Returns a new [NotifyMeRequest] instance.
  NotifyMeRequest({
    required this.lat,

    required this.lng,

    this.phone,

    this.addressText,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotifyMeRequest &&
          other.lat == lat &&
          other.lng == lng &&
          other.phone == phone &&
          other.addressText == addressText;

  @override
  int get hashCode =>
      lat.hashCode +
      lng.hashCode +
      (phone == null ? 0 : phone.hashCode) +
      addressText.hashCode;

  factory NotifyMeRequest.fromJson(Map<String, dynamic> json) =>
      _$NotifyMeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$NotifyMeRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
