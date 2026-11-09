// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rating_tag_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_rating_tag_count.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderRatingTagCount {
  /// Returns a new [RiderRatingTagCount] instance.
  RiderRatingTagCount({required this.tag, required this.count});

  @JsonKey(
    name: r'tag',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RatingTagEnum.unknownDefaultOpenApi,
  )
  final RatingTagEnum tag;

  @JsonKey(name: r'count', required: true, includeIfNull: false)
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderRatingTagCount && other.tag == tag && other.count == count;

  @override
  int get hashCode => tag.hashCode + count.hashCode;

  factory RiderRatingTagCount.fromJson(Map<String, dynamic> json) =>
      _$RiderRatingTagCountFromJson(json);

  Map<String, dynamic> toJson() => _$RiderRatingTagCountToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
