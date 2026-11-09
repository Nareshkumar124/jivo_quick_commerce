// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rating_tag_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_rating_create_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderRatingCreateRequest {
  /// Returns a new [OrderRatingCreateRequest] instance.
  OrderRatingCreateRequest({
    required this.orderStars,

    this.riderStars,

    this.tags,

    this.comment,
  });

  /// 1 to 5 stars.
  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'order_stars', required: true, includeIfNull: false)
  final int orderStars;

  /// Optional: 1 to 5 stars for the rider who delivered the order.
  // minimum: 1
  // maximum: 5
  @JsonKey(name: r'rider_stars', required: false, includeIfNull: false)
  final int? riderStars;

  /// Optional tags. The app offers ON_TIME, WELL_PACKED, FRESH_PRODUCTS and POLITE_RIDER for 4-5 stars and LATE_DELIVERY, DAMAGED_ITEMS, MISSING_ITEMS and RUDE_RIDER for 1-3 (not enforced). POLITE_RIDER and RUDE_RIDER need `rider_stars`.
  @JsonKey(
    name: r'tags',
    required: false,
    includeIfNull: false,
    unknownEnumValue: RatingTagEnum.unknownDefaultOpenApi,
  )
  final List<RatingTagEnum>? tags;

  /// Optional, plain text, at most 500 characters.
  @JsonKey(name: r'comment', required: false, includeIfNull: false)
  final String? comment;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderRatingCreateRequest &&
          other.orderStars == orderStars &&
          other.riderStars == riderStars &&
          other.tags == tags &&
          other.comment == comment;

  @override
  int get hashCode =>
      orderStars.hashCode +
      (riderStars == null ? 0 : riderStars.hashCode) +
      tags.hashCode +
      comment.hashCode;

  factory OrderRatingCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$OrderRatingCreateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OrderRatingCreateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
