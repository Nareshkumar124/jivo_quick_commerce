import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/rating/data/api_rating_repository.dart';
import 'package:rider_app/features/rating/data/fake_rating_backend.dart';
import 'package:rider_app/features/rating/domain/rider_rating.dart';
import 'package:rider_app/features/rating/presentation/rating_providers.dart';

import '../../helpers/canned_http.dart';
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

    test('staging and prod read GET /rider/ratings/, never the fake', () async {
      for (final flavor in [Flavor.staging, Flavor.prod]) {
        final container = await RiderTestHarness(flavor: flavor).container();
        expect(
          container.read(ratingRepositoryProvider),
          isA<ApiRatingRepository>(),
          reason: flavor.name,
        );
      }
      final dev = await RiderTestHarness().container();
      expect(dev.read(ratingRepositoryProvider), isA<FakeRatingBackend>());
    });
  });

  group('ApiRatingRepository', () {
    const path = '/api/v1/rider/ratings/';

    test('maps rider_ratings_list and pages by before_id', () async {
      final http = CannedAdapter();
      http.answers[path] = const Canned(200, {
        // The server's rounding: shown as is, never recomputed.
        'rating_avg': '4.7',
        'ratings_count': 23,
        'tag_counts': [
          {'tag': 'ON_TIME', 'count': 12},
          {'tag': 'WELL_PACKED', 'count': 5},
          {'tag': 'RUDE_RIDER', 'count': 1},
        ],
        'results': [
          {
            'id': 90,
            'stars': 5,
            'tags': ['ON_TIME', 'FRESH_PRODUCTS'],
            'rated_at': '2026-11-06T10:00:00Z',
            'order_number': 'JV-261106-000090',
          },
          {
            'id': 88,
            'stars': 3,
            'tags': <String>[],
            'rated_at': '2026-11-05T10:00:00Z',
            'order_number': 'JV-261105-000088',
          },
        ],
        'next': 'http://localhost:8001/api/v1/rider/ratings/?before_id=88',
      });
      final repo = ApiRatingRepository(cannedApi(http));
      final summary = await repo.fetch();
      expect(summary.average, '4.7');
      expect(summary.count, 23);
      // Store tags (WELL_PACKED) are not the rider's: dropped.
      expect(summary.tagCounts.map((t) => (t.tag, t.count)), [
        (RatingTag.onTime, 12),
        (RatingTag.rudeRider, 1),
      ]);
      expect(summary.recent.map((r) => r.id), [90, 88]);
      expect(summary.recent.first.tags, [RatingTag.onTime, RatingTag.unknown]);
      expect(summary.recent.first.ratedAt, DateTime.utc(2026, 11, 6, 10));
      expect(summary.recent.first.orderNumber, 'JV-261106-000090');
      expect(summary.nextBeforeId, 88);
      expect(
        http.requests.last.queryParameters.containsKey('before_id'),
        isFalse,
      );

      await repo.fetch(beforeId: 88);
      expect(http.requests.last.queryParameters['before_id'], 88);
    });

    test('no ratings yet: a null average; errors arrive as ApiError', () async {
      final http = CannedAdapter();
      http.answers[path] = const Canned(200, {
        'rating_avg': null,
        'ratings_count': 0,
        'tag_counts': <Object?>[],
        'results': <Object?>[],
        'next': null,
      });
      final repo = ApiRatingRepository(cannedApi(http));
      final empty = await repo.fetch();
      expect(empty.average, isNull);
      expect(empty.isEmpty, isTrue);
      expect(empty.nextBeforeId, isNull);

      http.answers[path] = Canned(403, errorBody('PERMISSION_DENIED'));
      await expectLater(
        repo.fetch(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.permissionDenied,
          ),
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

    testWidgets('a failed load can be retried', (tester) async {
      final h = RiderTestHarness();
      h.ratings.failNext = const ApiError(code: ApiErrorCode.network);
      await pushFromHome(tester, h, Routes.rating);
      expect(byKey('paged-error'), findsOneWidget);
      await tester.tap(byKey('paged-retry'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'rating-average'), '4.6');
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
