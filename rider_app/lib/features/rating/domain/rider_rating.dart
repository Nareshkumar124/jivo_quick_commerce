import 'package:flutter/foundation.dart';
import 'package:jivo_core/jivo_core.dart';

/// "My rating" (04 §2.9, P7): the rider's average, how many ratings it is
/// based on, the tags customers chose and the recent ratings. No customer
/// data: no name, phone, address or comment (a comment is free text and may
/// carry PII).
///
/// TODO(api): the shapes are the app's proposal until the backend's P7
/// ratings API lands (api-requests, P7 rider report):
/// `GET /rider/ratings/?before_id=` →
/// `{rating_avg ("4.8" or null), ratings_count, tag_counts [{tag, count}],
///   results [{id, stars, tags[], rated_at, order_number}], next}`.

/// Rider-facing rating tags (the rider subset of api-requests #34).
enum RatingTag {
  onTime('ON_TIME', positive: true),
  politeRider('POLITE_RIDER', positive: true),
  lateDelivery('LATE_DELIVERY', positive: false),
  rudeRider('RUDE_RIDER', positive: false),
  unknown(null, positive: true);

  const RatingTag(this.wireValue, {required this.positive});

  final String? wireValue;
  final bool positive;

  static RatingTag fromWire(String? value) {
    for (final tag in values) {
      if (tag.wireValue != null && tag.wireValue == value) return tag;
    }
    return unknown;
  }
}

/// One customer's rating of the rider.
@immutable
class RiderRating {
  const RiderRating({
    required this.id,
    required this.stars,
    required this.tags,
    required this.ratedAt,
    this.orderNumber,
  });

  final int id;

  /// 1–5.
  final int stars;
  final List<RatingTag> tags;
  final DateTime ratedAt;
  final String? orderNumber;
}

@immutable
class TagCount {
  const TagCount(this.tag, this.count);

  final RatingTag tag;
  final int count;
}

/// The rider's ratings: the server's average and counts, and one page of
/// recent ratings.
@immutable
class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    required this.tagCounts,
    required this.recent,
    this.nextBeforeId,
  });

  /// As the server sends it (`"4.8"`), null with no ratings yet. Never
  /// computed on the phone.
  final String? average;
  final int count;

  /// Most frequent first, unknown tags dropped.
  final List<TagCount> tagCounts;
  final List<RiderRating> recent;
  final int? nextBeforeId;

  bool get isEmpty => count == 0 && recent.isEmpty;

  /// Whole stars to fill for [average] (rounded to the nearest half,
  /// returned in halves: 9 = 4.5 stars). 0 without an average.
  int get halfStars {
    final value = double.tryParse(average ?? '');
    if (value == null) return 0;
    return (value * 2).round().clamp(0, 10);
  }
}

/// Throws jivo_core's [ApiError].
abstract interface class RatingRepository {
  /// The summary with the newest ratings; [beforeId] pages back.
  Future<RatingSummary> fetch({int? beforeId});
}

/// Builds with the rider work screens but no ratings API yet: every call
/// is 404, and the screen says ratings are not available yet.
class UnavailableRatingRepository implements RatingRepository {
  const UnavailableRatingRepository();

  @override
  Future<RatingSummary> fetch({int? beforeId}) async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
}
