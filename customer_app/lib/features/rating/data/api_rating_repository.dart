import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show JivoApi, OrderRating, OrderRatingCreateRequest, RatingTagEnum;
import 'package:jivo_core/jivo_core.dart';

import '../domain/order_rating.dart';
import 'rating_repository.dart';

/// Order and rider ratings on the P7 API (`orders_rating_retrieve`,
/// `orders_rating_create`; `06 §2.6`, api-requests #34).
///
/// `GET /orders/{id}/rating/` is 404 until the order is rated (mapped to
/// null). `POST` is 201 with the rating; 400 `VALIDATION_ERROR` when the
/// order isn't delivered or is already rated (`details.reason`), for rider
/// tags without `rider_stars`, or `rider_stars` on an order without a
/// rider.
class ApiRatingRepository implements RatingRepository {
  const ApiRatingRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<OrderRating?> fetch(int orderId) async {
    try {
      final response = await _api.getOrdersApi().ordersRatingRetrieve(
        id: orderId,
      );
      return ratingFromApi(response.data!);
    } on DioException catch (e) {
      final error = ApiError.fromDioException(e);
      if (error.code == ApiErrorCode.notFound) return null;
      throw error;
    }
  }

  @override
  Future<OrderRating> submit(int orderId, OrderRatingInput input) async {
    try {
      final response = await _api.getOrdersApi().ordersRatingCreate(
        id: orderId,
        orderRatingCreateRequest: ratingRequestFromInput(input),
      );
      return ratingFromApi(response.data!);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// The request body. Tags go in a stable order; `rider_stars` is left out
/// when the rider isn't rated, and so are rider tags (the server refuses
/// them without it).
api.OrderRatingCreateRequest ratingRequestFromInput(OrderRatingInput input) {
  final riderStars = input.riderStars;
  return api.OrderRatingCreateRequest(
    orderStars: input.orderStars,
    riderStars: riderStars,
    tags: [
      for (final tag in RatingTag.values)
        if (input.tags.contains(tag) && (riderStars != null || !tag.needsRider))
          _tagToApi(tag),
    ],
    comment: input.comment.trim(),
  );
}

api.RatingTagEnum _tagToApi(RatingTag tag) =>
    api.RatingTagEnum.values.firstWhere((e) => e.value == tag.wireValue);

/// A rating as the server returns it. Tags the app doesn't know (the
/// generated `unknownDefaultOpenApi`) are dropped, so a tag the backend
/// adds later doesn't break the screen.
OrderRating ratingFromApi(api.OrderRating r) => OrderRating(
  orderStars: r.orderStars,
  riderStars: r.riderStars,
  tags: {for (final tag in r.tags) ?RatingTag.fromWire(tag.value)},
  comment: r.comment,
  createdAt: r.createdAt.toUtc(),
);
