import 'package:flutter/foundation.dart';

/// Quick tags on an order rating (`03 §2.10` "1–5 stars + tags").
///
/// TODO(api): the tag codes are the app's proposal for
/// `POST /orders/{id}/rating/` (`06 §2.6`, P7); the backend confirms them.
enum RatingTag {
  onTime('ON_TIME', positive: true),
  wellPacked('WELL_PACKED', positive: true),
  freshProducts('FRESH_PRODUCTS', positive: true),
  politeRider('POLITE_RIDER', positive: true),
  lateDelivery('LATE_DELIVERY', positive: false),
  damagedItems('DAMAGED_ITEMS', positive: false),
  missingItems('MISSING_ITEMS', positive: false),
  rudeRider('RUDE_RIDER', positive: false);

  const RatingTag(this.wireValue, {required this.positive});

  final String wireValue;

  /// Offered with 4–5 stars; the others with 1–3.
  final bool positive;

  static RatingTag? fromWire(String value) {
    for (final tag in values) {
      if (tag.wireValue == value) return tag;
    }
    return null;
  }

  /// The tags offered for [stars] (none before a star is picked).
  static List<RatingTag> forStars(int stars) => stars == 0
      ? const []
      : [
          for (final tag in values)
            if (tag.positive == (stars >= 4)) tag,
        ];
}

/// The longest comment the app sends.
const ratingCommentMaxLength = 500;

/// What the customer submits (`06 §2.6`: `{order_stars, rider_stars, tags,
/// comment}`).
@immutable
class OrderRatingInput {
  const OrderRatingInput({
    required this.orderStars,
    this.riderStars,
    this.tags = const {},
    this.comment = '',
  }) : assert(orderStars >= 1 && orderStars <= 5);

  final int orderStars;

  /// The delivery partner's rating; null when skipped.
  final int? riderStars;
  final Set<RatingTag> tags;
  final String comment;
}

/// A submitted rating, as the server returns it.
@immutable
class OrderRating {
  const OrderRating({
    required this.orderStars,
    required this.createdAt,
    this.riderStars,
    this.tags = const {},
    this.comment = '',
  });

  final int orderStars;
  final int? riderStars;
  final Set<RatingTag> tags;
  final String comment;
  final DateTime createdAt;
}
