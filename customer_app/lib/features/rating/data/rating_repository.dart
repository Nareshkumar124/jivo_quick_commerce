import 'package:jivo_core/jivo_core.dart';

import '../domain/order_rating.dart';

/// Order and rider ratings (`03 §2.10` Rate, `06 §2.6`
/// `POST /orders/{id}/rating/`, Phase 7).
///
/// `ApiRatingRepository` in every flavor; [FakeRatingRepository] with the
/// dev flavor's `FAKE_API=true` and in tests.
abstract interface class RatingRepository {
  /// The order's rating, or null when the customer hasn't rated it.
  /// Throws [ApiError].
  Future<OrderRating?> fetch(int orderId);

  /// Rates a delivered order once. Throws [ApiError] (`VALIDATION_ERROR`
  /// when already rated or not delivered).
  Future<OrderRating> submit(int orderId, OrderRatingInput input);
}

/// A build without rating (kept for tests and future flavors).
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
    if (input.riderStars == null && input.tags.any((t) => t.needsRider)) {
      // As the server: rider tags need rider stars.
      throw const ApiError(
        code: ApiErrorCode.validationError,
        statusCode: 400,
        details: {
          'tags': ['Rate the rider to use rider tags.'],
        },
      );
    }
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
