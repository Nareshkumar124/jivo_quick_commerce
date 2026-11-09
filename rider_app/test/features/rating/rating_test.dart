import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/rating/data/fake_rating_backend.dart';
import 'package:rider_app/features/rating/domain/rider_rating.dart';
import 'package:rider_app/features/rating/presentation/rating_providers.dart';

import '../../helpers/records_helpers.dart';
import '../../helpers/rider_app_harness.dart';

RatingSummary _summary(String? average) => RatingSummary(
  average: average,
  count: 3,
  tagCounts: const [],
  recent: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('domain', () {
    test('halfStars rounds the server average to half stars', () {
      expect(_summary('4.8').halfStars, 10);
      expect(_summary('4.6').halfStars, 9);
      expect(_summary('4.2').halfStars, 8);
      expect(_summary('1.0').halfStars, 2);
      expect(_summary(null).halfStars, 0);
      expect(_summary('n/a').halfStars, 0);
      expect(_summary(null).isEmpty, isFalse);
    });

    test('tags map from the wire; unknown tags are kept as unknown', () {
      expect(RatingTag.fromWire('ON_TIME'), RatingTag.onTime);
      expect(RatingTag.fromWire('RUDE_RIDER').positive, isFalse);
      expect(RatingTag.fromWire('WELL_PACKED'), RatingTag.unknown);
    });

    test('the fake pages back by before_id and counts tags', () async {
      final fake = FakeRatingBackend(
        clock: () => DateTime.utc(2026, 11, 6),
        delay: Duration.zero,
      );
      final first = await fake.fetch();
      expect(first.average, '4.6');
      expect(first.count, 14);
      expect(first.recent, hasLength(10));
      expect(first.nextBeforeId, first.recent.last.id);
      expect(
        first.tagCounts.first.count,
        greaterThanOrEqualTo(first.tagCounts.last.count),
      );
      final second = await fake.fetch(beforeId: first.nextBeforeId);
      expect(second.recent, hasLength(4));
      expect(second.nextBeforeId, isNull);
      final none = FakeRatingBackend(
        clock: DateTime.now,
        delay: Duration.zero,
        ratings: const [],
      );
      final empty = await none.fetch();
      expect(empty.average, isNull);
      expect(empty.isEmpty, isTrue);
    });
  });

  group('providers', () {
    test('the controller loads the summary and more pages', () async {
      final h = RiderTestHarness();
      final container = await h.container();
      final sub = container.listen(myRatingProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(sub.read().header?.average, '4.6');
      expect(sub.read().items, hasLength(10));
      await container.read(myRatingProvider.notifier).loadMore();
      expect(sub.read().items, hasLength(14));
      expect(sub.read().hasMore, isFalse);
    });

    test('builds on the real API have no ratings yet (404)', () async {
      final h = RiderTestHarness(flavor: Flavor.staging);
      final container = await h.container();
      expect(
        container.read(ratingRepositoryProvider),
        isA<UnavailableRatingRepository>(),
      );
      await expectLater(
        container.read(ratingRepositoryProvider).fetch(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
        ),
      );
    });
  });

  group('screen', () {
    testWidgets('profile rating opens My rating with average, tags and list', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await openFromHome(tester, h, 'home-profile');
      await tester.tap(byKey('profile-rating'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'rating-average'), '4.6');
      expect(textOf(tester, 'rating-count'), 'From 14 ratings');
      expect(byKey('rating-tag-ON_TIME'), findsOneWidget);
      expect(byKey('rating-500'), findsOneWidget);
      // No customer data on a rating: stars, tags, order number and date.
      expect(find.text('JV-261102-001240'), findsOneWidget);
    });

    testWidgets('a failed load can be retried; no API says not available', (
      tester,
    ) async {
      final h = RiderTestHarness();
      h.ratings.failNext = const ApiError(
        code: ApiErrorCode.notFound,
        statusCode: 404,
      );
      await pushFromHome(tester, h, Routes.rating);
      expect(byKey('rating-unavailable'), findsOneWidget);
    });

    testWidgets('no ratings yet', (tester) async {
      final h = RiderTestHarness();
      h.ratings.ratings.clear();
      await pushFromHome(tester, h, Routes.rating);
      expect(find.text('No ratings yet'), findsOneWidget);
      expect(textOf(tester, 'rating-average'), '–');
    });
  });
}
