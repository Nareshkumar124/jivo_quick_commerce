// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_offer.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'current_offer.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CurrentOffer {
  /// Returns a new [CurrentOffer] instance.
  CurrentOffer({required this.offer, required this.serverTime});

  /// The pending offer, or null.
  @JsonKey(name: r'offer', required: true, includeIfNull: true)
  final RiderOffer? offer;

  /// Server clock, for the countdown.
  @JsonKey(name: r'server_time', required: true, includeIfNull: false)
  final DateTime serverTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CurrentOffer &&
          other.offer == offer &&
          other.serverTime == serverTime;

  @override
  int get hashCode =>
      (offer == null ? 0 : offer.hashCode) + serverTime.hashCode;

  factory CurrentOffer.fromJson(Map<String, dynamic> json) =>
      _$CurrentOfferFromJson(json);

  Map<String, dynamic> toJson() => _$CurrentOfferToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
