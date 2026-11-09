// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rating_tag_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_rating_item.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderRatingItem {
  /// Returns a new [RiderRatingItem] instance.
  RiderRatingItem({
    required this.id,

    required this.stars,

    required this.tags,

    required this.ratedAt,

    required this.orderNumber,
  });

  /// Use as `before_id` for older ratings.
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'stars', required: true, includeIfNull: false)
  final int stars;

  @JsonKey(
    name: r'tags',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RatingTagEnum.unknownDefaultOpenApi,
  )
  final List<RatingTagEnum> tags;

  @JsonKey(name: r'rated_at', required: true, includeIfNull: false)
  final DateTime ratedAt;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderRatingItem &&
          other.id == id &&
          other.stars == stars &&
          other.tags == tags &&
          other.ratedAt == ratedAt &&
          other.orderNumber == orderNumber;

  @override
  int get hashCode =>
      id.hashCode +
      stars.hashCode +
      tags.hashCode +
      ratedAt.hashCode +
      orderNumber.hashCode;

  factory RiderRatingItem.fromJson(Map<String, dynamic> json) =>
      _$RiderRatingItemFromJson(json);

  Map<String, dynamic> toJson() => _$RiderRatingItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
