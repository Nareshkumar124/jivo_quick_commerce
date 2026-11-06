import 'package:dio/dio.dart';
import 'package:jivo_core/jivo_core.dart';

import '../domain/order_rating.dart';
import 'rating_repository.dart';

/// Order and rider ratings on the P7 API (`06 §2.6`).
///
/// TODO(api): written against the app's proposal in `docs/api-requests.md`
/// #34 because the backend contract isn't in `backend/openapi/schema.yaml`
/// yet: `POST /orders/{id}/rating/` with `{order_stars, rider_stars, tags,
/// comment}` returns the rating (201), and `GET /orders/{id}/rating/`
/// returns it or 404 when unrated. It is built only when
/// `ratingApiBound` (`app/repositories.dart`) is true. Once the endpoints
/// are in the schema, regenerate `jivo_api` and swap the raw [Dio] calls
/// for the generated `orders_rating_*` operations; the mappers stay.
class ApiRatingRepository implements RatingRepository {
  const ApiRatingRepository(this._dio);

  final Dio _dio;

  static String _path(int orderId) => '/api/v1/orders/$orderId/rating/';

  @override
  Future<OrderRating?> fetch(int orderId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path(orderId));
      return ratingFromJson(response.data!);
    } on DioException catch (e) {
      final error = ApiError.fromDioException(e);
      if (error.code == ApiErrorCode.notFound) return null;
      throw error;
    }
  }

  @override
  Future<OrderRating> submit(int orderId, OrderRatingInput input) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _path(orderId),
        data: ratingInputToJson(input),
      );
      return ratingFromJson(response.data!);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// The request body (`06 §2.6`). Tags go in a stable order.
Map<String, Object?> ratingInputToJson(OrderRatingInput input) => {
  'order_stars': input.orderStars,
  'rider_stars': input.riderStars,
  'tags': [
    for (final tag in RatingTag.values)
      if (input.tags.contains(tag)) tag.wireValue,
  ],
  'comment': input.comment.trim(),
};

/// A rating as the server returns it. Unknown tag codes are dropped, so a
/// tag the backend adds later doesn't break the screen.
OrderRating ratingFromJson(Map<String, dynamic> json) {
  final tags = json['tags'];
  final riderStars = json['rider_stars'];
  final createdAt = json['created_at'];
  return OrderRating(
    orderStars: (json['order_stars'] as num).toInt(),
    riderStars: riderStars is num ? riderStars.toInt() : null,
    tags: {
      if (tags is List)
        for (final code in tags)
          if (code is String) ?RatingTag.fromWire(code),
    },
    comment: (json['comment'] as String?) ?? '',
    createdAt: createdAt is String
        ? DateTime.parse(createdAt).toUtc()
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}
