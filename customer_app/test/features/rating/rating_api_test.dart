import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/notifications/data/notification_repository.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/rating/data/api_rating_repository.dart';
import 'package:customer_app/features/rating/data/rating_repository.dart';
import 'package:customer_app/features/rating/domain/order_rating.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/features/auth/data/fake_token_refresher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../../helpers/fake_http.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_config.dart';

/// The ratings API binding (P7, `docs/api-requests.md` #34) and the rate
/// prompt from the inbox.
void main() {
  (int, Object?) example(String key) =>
      (int.parse(key.split('/')[1]), contractExample(key));

  Matcher apiError(ApiErrorCode code) =>
      throwsA(isA<ApiError>().having((e) => e.code, 'code', code));

  group('ApiRatingRepository (orders_rating_*)', () {
    test('fetch maps the contract example with rider stars', () async {
      final http = FakeHttp(
        (_) => example('orders_rating_retrieve/200/OrderAndRider'),
      );
      final rating = await ApiRatingRepository(http.api()).fetch(7);
      expect(http.requests.single.path, '/api/v1/orders/7/rating/');
      expect(http.requests.single.method, 'GET');
      expect(rating!.orderStars, 5);
      expect(rating.riderStars, 5);
      expect(rating.tags, {
        RatingTag.onTime,
        RatingTag.wellPacked,
        RatingTag.politeRider,
      });
      expect(rating.comment, 'Quick delivery, thank you!');
      expect(rating.createdAt, DateTime.utc(2026, 11, 3, 7, 2));
    });

    test('fetch: an order-only rating has no rider stars', () async {
      final http = FakeHttp(
        (_) => example('orders_rating_retrieve/200/OrderOnly'),
      );
      final rating = await ApiRatingRepository(http.api()).fetch(7);
      expect(rating!.riderStars, isNull);
      expect(rating.tags, {RatingTag.damagedItems});
      expect(rating.comment, isEmpty);
    });

    test('fetch: unknown tags are dropped', () async {
      final http = FakeHttp(
        (_) => (
          200,
          {
            'order_stars': 4,
            'rider_stars': null,
            'tags': ['WELL_PACKED', 'SOMETHING_NEW'],
            'comment': 'Nice',
            'created_at': '2026-11-06T10:00:00Z',
          },
        ),
      );
      final rating = await ApiRatingRepository(http.api()).fetch(7);
      expect(rating!.tags, {RatingTag.wellPacked});
    });

    test('fetch: 404 means not rated yet', () async {
      final http = FakeHttp(
        (_) => example('orders_rating_retrieve/404/NOTRATED'),
      );
      expect(await ApiRatingRepository(http.api()).fetch(7), isNull);
    });

    test('fetch: other errors are ApiErrors', () async {
      final http = FakeHttp(
        (_) => example('orders_rating_retrieve/429/RATELIMITED'),
      );
      await expectLater(
        ApiRatingRepository(http.api()).fetch(7),
        apiError(ApiErrorCode.rateLimited),
      );
    });

    test('submit posts OrderRatingCreateRequest and maps the reply', () async {
      final http = FakeHttp(
        (_) => example('orders_rating_create/201/OrderAndRider'),
      );
      final rating = await ApiRatingRepository(http.api()).submit(
        9,
        const OrderRatingInput(
          orderStars: 5,
          riderStars: 5,
          tags: {RatingTag.politeRider, RatingTag.wellPacked, RatingTag.onTime},
          comment: '  Quick delivery, thank you!  ',
        ),
      );
      expect(http.requests.single.method, 'POST');
      expect(http.requests.single.path, '/api/v1/orders/9/rating/');
      expect(http.body(0), {
        'order_stars': 5,
        'rider_stars': 5,
        'tags': ['ON_TIME', 'WELL_PACKED', 'POLITE_RIDER'],
        'comment': 'Quick delivery, thank you!',
      });
      expect(rating.riderStars, 5);
      expect(rating.tags, contains(RatingTag.politeRider));
    });

    test('submit without rider stars leaves rider_stars and rider tags '
        'out', () async {
      final http = FakeHttp(
        (_) => example('orders_rating_create/201/OrderOnly'),
      );
      await ApiRatingRepository(http.api()).submit(
        9,
        const OrderRatingInput(
          orderStars: 2,
          tags: {RatingTag.damagedItems, RatingTag.rudeRider},
        ),
      );
      expect(http.body(0), {
        'order_stars': 2,
        'tags': ['DAMAGED_ITEMS'],
        'comment': '',
      });
    });

    test('submit errors map to their codes', () async {
      for (final (key, code) in [
        ('orders_rating_create/400/ALREADYRATED', ApiErrorCode.validationError),
        ('orders_rating_create/400/NOTDELIVERED', ApiErrorCode.validationError),
        ('orders_rating_create/400/RiderTags', ApiErrorCode.validationError),
        ('orders_rating_create/400/NoRider', ApiErrorCode.validationError),
        ('orders_rating_create/404/NOTFOUND', ApiErrorCode.notFound),
        ('orders_rating_create/429/RATELIMITED', ApiErrorCode.rateLimited),
      ]) {
        final http = FakeHttp((_) => example(key));
        await expectLater(
          ApiRatingRepository(http.api())
              .submit(9, const OrderRatingInput(orderStars: 2)),
          apiError(code),
          reason: key,
        );
      }
    });
  });

  group('wiring', () {
    ProviderContainer containerFor(Flavor flavor, {bool fake = false}) {
      final container = ProviderContainer(
        overrides: [
          appEnvProvider.overrideWithValue(
            AppEnv(
              flavor: flavor,
              apiBaseUrl: Uri.parse('https://api.example.in'),
              useFakeApi: fake,
            ),
          ),
          clientInfoProvider.overrideWithValue(testClientInfo),
          sessionProvider.overrideWithValue(
            SessionManager(
              store: InMemoryTokenStore(),
              refresher: FakeTokenRefresher(),
            ),
          ),
          appControlProvider.overrideWithValue(AppControlSignals()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    for (final flavor in Flavor.values) {
      test('${flavor.name}: rating is on the real API', () {
        final container = containerFor(flavor);
        expect(container.read(ratingAvailableProvider), isTrue);
        expect(
          container.read(ratingRepositoryProvider),
          isA<ApiRatingRepository>(),
        );
      });
    }

    test('dev + FAKE_API uses the fake; staging ignores FAKE_API', () {
      expect(
        containerFor(Flavor.dev, fake: true).read(ratingRepositoryProvider),
        isA<FakeRatingRepository>(),
      );
      expect(
        containerFor(Flavor.staging, fake: true).read(ratingRepositoryProvider),
        isA<ApiRatingRepository>(),
      );
    });
  });

  group('rate prompt from the inbox', () {
    late FakeCommerceBackend backend;
    late FakeRatingRepository ratings;

    setUp(() {
      backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
      ratings = FakeRatingRepository();
    });

    Future<int> openFromInbox(WidgetTester tester) async {
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.delivered)
          .id;
      final app = TestApp(
        tokens: signedInTokens,
        commerce: backend,
        notifications: FakeNotificationRepository(
          items: [
            InboxNotification(
              id: 1,
              title: 'Delivered',
              body: 'How was it? Rate your order.',
              createdAt: DateTime.utc(2026, 11, 6),
              link: Uri.parse('jivo://orders/$id/rate'),
            ),
          ],
        ),
        extraOverrides: [
          trackingAvailableProvider.overrideWithValue(false),
          ratingAvailableProvider.overrideWithValue(true),
          ratingRepositoryProvider.overrideWithValue(ratings),
        ],
      );
      await app.pump(tester);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-notifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delivered'));
      await tester.pumpAndSettle();
      return id;
    }

    testWidgets('an unrated order opens the rate form', (tester) async {
      await openFromInbox(tester);
      expect(find.byKey(const Key('rate-order')), findsOneWidget);
    });

    testWidgets('an already rated order shows the rating, not the form', (
      tester,
    ) async {
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.delivered)
          .id;
      await ratings.submit(
        id,
        const OrderRatingInput(orderStars: 5, tags: {RatingTag.onTime}),
      );
      await openFromInbox(tester);
      expect(find.byKey(const Key('rate-order')), findsNothing);
      expect(find.byKey(const Key('rate-order-done')), findsOneWidget);
      expect(find.text('You rated this order 5 stars'), findsOneWidget);
      expect(find.text('On time'), findsOneWidget);
      // No rider stars: no rider row.
      expect(find.byKey(const Key('rated-rider-stars')), findsNothing);
    });

    testWidgets('the rated view shows the rider stars when given', (
      tester,
    ) async {
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.delivered)
          .id;
      await ratings.submit(
        id,
        const OrderRatingInput(
          orderStars: 5,
          riderStars: 4,
          tags: {RatingTag.politeRider},
        ),
      );
      await openFromInbox(tester);
      expect(find.byKey(const Key('rated-rider-stars')), findsOneWidget);
      expect(
        find.text('You rated the delivery partner 4 stars'),
        findsOneWidget,
      );
      expect(find.text('Polite delivery partner'), findsOneWidget);
    });
  });
}
