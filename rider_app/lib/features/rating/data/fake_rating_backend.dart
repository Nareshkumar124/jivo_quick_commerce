import '../../../shared/fake_api_endpoint.dart';
import '../domain/rider_rating.dart';

/// The rider's ratings in memory (dev flavor `FAKE_API` builds and tests
/// only, DL-30/DL-32). Pages by `before_id`, like `GET /rider/ratings/`.
class FakeRatingBackend extends FakeApiEndpoint implements RatingRepository {
  FakeRatingBackend({
    required DateTime Function() clock,
    super.delay = const Duration(milliseconds: 300),
    super.pageSize = 10,
    List<RiderRating>? ratings,
    this.average = '4.6',
  }) : ratings = ratings ?? _seed(clock().toUtc());

  /// Newest first.
  final List<RiderRating> ratings;
  String? average;

  static List<RiderRating> _seed(DateTime now) => [
    for (var i = 0; i < 14; i++)
      RiderRating(
        id: 500 - i,
        stars: const [5, 5, 4, 5, 3, 5, 4, 5, 5, 2, 5, 4, 5, 5][i],
        tags: switch (i % 5) {
          0 => const [RatingTag.onTime, RatingTag.politeRider],
          1 => const [RatingTag.politeRider],
          2 => const [RatingTag.onTime],
          3 => const [],
          _ => const [RatingTag.lateDelivery],
        },
        ratedAt: now.subtract(Duration(hours: 5 + i * 9)),
        orderNumber: 'JV-261102-${(1240 - i).toString().padLeft(6, '0')}',
      ),
  ];

  @override
  Future<RatingSummary> fetch({int? beforeId}) async {
    await recordCall('ratings ${beforeId ?? '-'}');
    final from = beforeId == null
        ? 0
        : ratings.indexWhere((r) => r.id < beforeId);
    final rest = from < 0 ? const <RiderRating>[] : ratings.sublist(from);
    final page = rest.take(pageSize).toList();
    final counts = <RatingTag, int>{};
    for (final rating in ratings) {
      for (final tag in rating.tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final tagCounts = [
      for (final entry in counts.entries) TagCount(entry.key, entry.value),
    ]..sort((a, b) => b.count.compareTo(a.count));
    return RatingSummary(
      average: ratings.isEmpty ? null : average,
      count: ratings.length,
      tagCounts: tagCounts,
      recent: page,
      nextBeforeId: rest.length > pageSize ? page.last.id : null,
    );
  }
}
