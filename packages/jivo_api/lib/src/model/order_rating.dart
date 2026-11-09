// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rating_tag_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_rating.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderRating {
  /// Returns a new [OrderRating] instance.
  OrderRating({
    required this.orderStars,

    required this.riderStars,

    required this.tags,

    required this.comment,

    required this.createdAt,
  });

  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'order_stars', required: true, includeIfNull: false)
  final int orderStars;

  /// Null when the rider was not rated.
  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'rider_stars', required: true, includeIfNull: true)
  final int? riderStars;

  @JsonKey(
    name: r'tags',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RatingTagEnum.unknownDefaultOpenApi,
  )
  final List<RatingTagEnum> tags;

  /// Plain text; may be empty.
  @JsonKey(name: r'comment', required: true, includeIfNull: false)
  final String comment;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderRating &&
          other.orderStars == orderStars &&
          other.riderStars == riderStars &&
          other.tags == tags &&
          other.comment == comment &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      orderStars.hashCode +
      (riderStars == null ? 0 : riderStars.hashCode) +
      tags.hashCode +
      comment.hashCode +
      createdAt.hashCode;

  factory OrderRating.fromJson(Map<String, dynamic> json) =>
      _$OrderRatingFromJson(json);

  Map<String, dynamic> toJson() => _$OrderRatingToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
