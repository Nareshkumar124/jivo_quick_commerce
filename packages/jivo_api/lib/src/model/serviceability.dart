// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/store_status.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'serviceability.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Serviceability {
  /// Returns a new [Serviceability] instance.
  Serviceability({
    required this.serviceable,

    required this.store,

    required this.etaMinutes,

    required this.message,
  });

  /// True when the point is inside an active store's service area (whether or not the store is open). False: show 'We're not in your area yet' with Notify me.
  @JsonKey(name: r'serviceable', required: true, includeIfNull: false)
  final bool serviceable;

  /// The store that serves this point (the nearest open one when service areas overlap). Null when not serviceable.
  @JsonKey(name: r'store', required: true, includeIfNull: true)
  final StoreStatus? store;

  /// Estimated delivery time in minutes for the home header ('Delivery in 14 mins'), 08 §8. Null when not serviceable or when the store is closed.
  // minimum: 1
  @JsonKey(name: r'eta_minutes', required: true, includeIfNull: true)
  final int? etaMinutes;

  /// Text to show when the location is not serviceable or the store is closed (times in IST). Null when serviceable and open.
  @JsonKey(name: r'message', required: true, includeIfNull: true)
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Serviceability &&
          other.serviceable == serviceable &&
          other.store == store &&
          other.etaMinutes == etaMinutes &&
          other.message == message;

  @override
  int get hashCode =>
      serviceable.hashCode +
      (store == null ? 0 : store.hashCode) +
      (etaMinutes == null ? 0 : etaMinutes.hashCode) +
      (message == null ? 0 : message.hashCode);

  factory Serviceability.fromJson(Map<String, dynamic> json) =>
      _$ServiceabilityFromJson(json);

  Map<String, dynamic> toJson() => _$ServiceabilityToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
