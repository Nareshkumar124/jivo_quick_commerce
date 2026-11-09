import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show JivoApi, RiderRatingItem, RiderRatingsPage;
import 'package:jivo_core/jivo_core.dart';

import '../../../shared/paging.dart';
import '../domain/rider_rating.dart';

/// `GET /rider/ratings/` (`rider_ratings_list`, P7) through the generated
/// client. The average is the server's one-decimal string, never computed
/// on the phone.
class ApiRatingRepository implements RatingRepository {
  const ApiRatingRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<RatingSummary> fetch({int? beforeId}) async {
    try {
      final body = (await _api.getRiderApi().riderRatingsList(
        beforeId: beforeId,
      )).data!;
      return ratingSummaryOf(body);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

RatingSummary ratingSummaryOf(api.RiderRatingsPage body) => RatingSummary(
  average: body.ratingAvg,
  count: body.ratingsCount,
  tagCounts: [
    for (final t in body.tagCounts)
      if (RatingTag.fromWire(t.tag.value) case final tag
          when tag != RatingTag.unknown)
        TagCount(tag, t.count),
  ],
  recent: [for (final r in body.results) _ratingOf(r)],
  nextBeforeId: beforeIdOfNext(body.next),
);

RiderRating _ratingOf(api.RiderRatingItem r) => RiderRating(
  id: r.id,
  stars: r.stars,
  tags: [for (final t in r.tags) RatingTag.fromWire(t.value)],
  ratedAt: r.ratedAt,
  orderNumber: r.orderNumber,
);
