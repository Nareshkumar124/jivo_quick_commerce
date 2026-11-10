// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_rating_tag_count.dart';
import 'package:jivo_api/src/model/rider_rating_item.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_ratings_page.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderRatingsPage {
  /// Returns a new [RiderRatingsPage] instance.
  RiderRatingsPage({
    required this.ratingAvg,

    required this.ratingsCount,

    required this.tagCounts,

    required this.results,

    required this.next,
  });

  /// Average stars, one decimal (\"4.8\"); null until the first rating.
  @JsonKey(name: r'rating_avg', required: true, includeIfNull: true)
  final String? ratingAvg;

  @JsonKey(name: r'ratings_count', required: true, includeIfNull: false)
  final int ratingsCount;

  /// Tags customers chose for the rider, most frequent first.
  @JsonKey(name: r'tag_counts', required: true, includeIfNull: false)
  final List<RiderRatingTagCount> tagCounts;

  /// Newest first.
  @JsonKey(name: r'results', required: true, includeIfNull: false)
  final List<RiderRatingItem> results;

  /// The next (older) page, `?before_id=`; null at the end.
  @JsonKey(name: r'next', required: true, includeIfNull: true)
  final String? next;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderRatingsPage &&
          other.ratingAvg == ratingAvg &&
          other.ratingsCount == ratingsCount &&
          other.tagCounts == tagCounts &&
          other.results == results &&
          other.next == next;

  @override
  int get hashCode =>
      (ratingAvg == null ? 0 : ratingAvg.hashCode) +
      ratingsCount.hashCode +
      tagCounts.hashCode +
      results.hashCode +
      (next == null ? 0 : next.hashCode);

  factory RiderRatingsPage.fromJson(Map<String, dynamic> json) =>
      _$RiderRatingsPageFromJson(json);

  Map<String, dynamic> toJson() => _$RiderRatingsPageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
