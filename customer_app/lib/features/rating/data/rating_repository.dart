import 'package:jivo_core/jivo_core.dart';

import '../domain/order_rating.dart';

/// Order and rider ratings (`03 §2.10` Rate, `06 §2.6`
/// `POST /orders/{id}/rating/`, Phase 7).
///
/// TODO(api): not in jivo_api yet. The screens run on
/// [FakeRatingRepository] (`FAKE_API=true`, tests) until the P7 contract;
/// the real-API build hides rating ([UnavailableRatingRepository]).
abstract interface class RatingRepository {
  /// The order's rating, or null when the customer hasn't rated it.
  /// Throws [ApiError].
  Future<OrderRating?> fetch(int orderId);

  /// Rates a delivered order once. Throws [ApiError] (`VALIDATION_ERROR`
  /// when already rated or not delivered).
  Future<OrderRating> submit(int orderId, OrderRatingInput input);
}

/// The real-API build until the P7 endpoint exists.
class UnavailableRatingRepository implements RatingRepository {
  const UnavailableRatingRepository();

  @override
  Future<OrderRating?> fetch(int orderId) async => null;

  @override
  Future<OrderRating> submit(int orderId, OrderRatingInput input) async =>
      throw const ApiError(code: ApiErrorCode.serviceUnavailable);
}

/// In-memory ratings (`FAKE_API=true` and tests).
class FakeRatingRepository implements RatingRepository {
  FakeRatingRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<int, OrderRating> ratings = {};

  /// Every submission, in order.
  final List<(int, OrderRatingInput)> submissions = [];

  /// When set, the next call throws it once.
  Object? failNext;

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<OrderRating?> fetch(int orderId) async {
    _maybeFail();
    return ratings[orderId];
  }

  @override
  Future<OrderRating> submit(int orderId, OrderRatingInput input) async {
    _maybeFail();
    if (ratings.containsKey(orderId)) {
      throw const ApiError(
        code: ApiErrorCode.validationError,
        statusCode: 400,
        serverMessage: 'This order is already rated.',
      );
    }
    submissions.add((orderId, input));
    return ratings[orderId] = OrderRating(
      orderStars: input.orderStars,
      riderStars: input.riderStars,
      tags: input.tags,
      comment: input.comment.trim(),
      createdAt: _clock().toUtc(),
    );
  }
}
