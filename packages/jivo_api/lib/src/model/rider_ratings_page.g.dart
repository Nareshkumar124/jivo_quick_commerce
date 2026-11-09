// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_ratings_page.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderRatingsPageCWProxy {
  RiderRatingsPage ratingAvg(String? ratingAvg);

  RiderRatingsPage ratingsCount(int ratingsCount);

  RiderRatingsPage tagCounts(List<RiderRatingTagCount> tagCounts);

  RiderRatingsPage results(List<RiderRatingItem> results);

  RiderRatingsPage next(String? next);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRatingsPage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRatingsPage(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRatingsPage call({
    String? ratingAvg,
    int ratingsCount,
    List<RiderRatingTagCount> tagCounts,
    List<RiderRatingItem> results,
    String? next,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderRatingsPage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderRatingsPage.copyWith.fieldName(...)`
class _$RiderRatingsPageCWProxyImpl implements _$RiderRatingsPageCWProxy {
  const _$RiderRatingsPageCWProxyImpl(this._value);

  final RiderRatingsPage _value;

  @override
  RiderRatingsPage ratingAvg(String? ratingAvg) => this(ratingAvg: ratingAvg);

  @override
  RiderRatingsPage ratingsCount(int ratingsCount) =>
      this(ratingsCount: ratingsCount);

  @override
  RiderRatingsPage tagCounts(List<RiderRatingTagCount> tagCounts) =>
      this(tagCounts: tagCounts);

  @override
  RiderRatingsPage results(List<RiderRatingItem> results) =>
      this(results: results);

  @override
  RiderRatingsPage next(String? next) => this(next: next);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderRatingsPage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderRatingsPage(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderRatingsPage call({
    Object? ratingAvg = const $CopyWithPlaceholder(),
    Object? ratingsCount = const $CopyWithPlaceholder(),
    Object? tagCounts = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
  }) {
    return RiderRatingsPage(
      ratingAvg: ratingAvg == const $CopyWithPlaceholder()
          ? _value.ratingAvg
          // ignore: cast_nullable_to_non_nullable
          : ratingAvg as String?,
      ratingsCount: ratingsCount == const $CopyWithPlaceholder()
          ? _value.ratingsCount
          // ignore: cast_nullable_to_non_nullable
          : ratingsCount as int,
      tagCounts: tagCounts == const $CopyWithPlaceholder()
          ? _value.tagCounts
          // ignore: cast_nullable_to_non_nullable
          : tagCounts as List<RiderRatingTagCount>,
      results: results == const $CopyWithPlaceholder()
          ? _value.results
          // ignore: cast_nullable_to_non_nullable
          : results as List<RiderRatingItem>,
      next: next == const $CopyWithPlaceholder()
          ? _value.next
          // ignore: cast_nullable_to_non_nullable
          : next as String?,
    );
  }
}

extension $RiderRatingsPageCopyWith on RiderRatingsPage {
  /// Returns a callable class that can be used as follows: `instanceOfRiderRatingsPage.copyWith(...)` or like so:`instanceOfRiderRatingsPage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderRatingsPageCWProxy get copyWith => _$RiderRatingsPageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderRatingsPage _$RiderRatingsPageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'RiderRatingsPage',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'rating_avg',
        'ratings_count',
        'tag_counts',
        'results',
        'next',
      ],
    );
    final val = RiderRatingsPage(
      ratingAvg: $checkedConvert('rating_avg', (v) => v as String?),
      ratingsCount: $checkedConvert('ratings_count', (v) => (v as num).toInt()),
      tagCounts: $checkedConvert(
        'tag_counts',
        (v) => (v as List<dynamic>)
            .map((e) => RiderRatingTagCount.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      results: $checkedConvert(
        'results',
        (v) => (v as List<dynamic>)
            .map((e) => RiderRatingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      next: $checkedConvert('next', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'ratingAvg': 'rating_avg',
    'ratingsCount': 'ratings_count',
    'tagCounts': 'tag_counts',
  },
);

Map<String, dynamic> _$RiderRatingsPageToJson(RiderRatingsPage instance) =>
    <String, dynamic>{
      'rating_avg': instance.ratingAvg,
      'ratings_count': instance.ratingsCount,
      'tag_counts': instance.tagCounts.map((e) => e.toJson()).toList(),
      'results': instance.results.map((e) => e.toJson()).toList(),
      'next': instance.next,
    };
