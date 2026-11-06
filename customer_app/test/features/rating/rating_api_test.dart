import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/notifications/data/notification_repository.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/rating/data/api_rating_repository.dart';
import 'package:customer_app/features/rating/data/rating_repository.dart';
import 'package:customer_app/features/rating/domain/order_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/test_app.dart';

/// The ratings API binding (P7, `docs/api-requests.md` #34) and the rate
/// prompt from the inbox.
void main() {
  final rated = {
    'order_stars': 4,
    'rider_stars': null,
    'tags': ['WELL_PACKED', 'SOMETHING_NEW'],
    'comment': 'Nice',
    'created_at': '2026-11-06T10:00:00Z',
  };

  group('ApiRatingRepository', () {
    test('fetch maps the rating; unknown tags are dropped', () async {
      final http = FakeHttp((_) => (200, rated));
      final rating = await ApiRatingRepository(http.api().dio).fetch(7);
      expect(http.requests.single.path, '/api/v1/orders/7/rating/');
      expect(http.requests.single.method, 'GET');
      expect(rating!.orderStars, 4);
      expect(rating.riderStars, isNull);
      expect(rating.tags, {RatingTag.wellPacked});
      expect(rating.comment, 'Nice');
      expect(rating.createdAt, DateTime.utc(2026, 11, 6, 10));
    });

    test('fetch: 404 means not rated yet', () async {
      final http = FakeHttp(
        (_) => (
          404,
          {
            'error': {'code': 'NOT_FOUND', 'message': 'x', 'details': {}},
          },
        ),
      );
      expect(await ApiRatingRepository(http.api().dio).fetch(7), isNull);
    });

    test('fetch: other errors are ApiErrors', () async {
      final http = FakeHttp(
        (_) => (
          500,
          {
            'error': {'code': 'SERVER_ERROR', 'message': 'x', 'details': {}},
          },
        ),
      );
      await expectLater(
        ApiRatingRepository(http.api().dio).fetch(7),
        throwsA(isA<ApiError>()),
      );
    });

    test('submit posts the body and maps the reply', () async {
      final http = FakeHttp((_) => (201, {...rated, 'rider_stars': 5}));
      final rating = await ApiRatingRepository(http.api().dio).submit(
        9,
        const OrderRatingInput(
          orderStars: 4,
          riderStars: 5,
          tags: {RatingTag.freshProducts, RatingTag.onTime},
          comment: '  Nice  ',
        ),
      );
      expect(http.requests.single.method, 'POST');
      expect(http.requests.single.path, '/api/v1/orders/9/rating/');
      expect(http.body(0), {
        'order_stars': 4,
        'rider_stars': 5,
        'tags': ['ON_TIME', 'FRESH_PRODUCTS'],
        'comment': 'Nice',
      });
      expect(rating.riderStars, 5);
    });

    test('submit: already rated is a VALIDATION_ERROR', () async {
      final http = FakeHttp(
        (_) => (
          400,
          {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'This order is already rated.',
              'details': {},
            },
          },
        ),
      );
      await expectLater(
        ApiRatingRepository(http.api().dio)
            .submit(9, const OrderRatingInput(orderStars: 2)),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.validationError,
          ),
        ),
      );
    });

    test('ratingFromJson tolerates a missing created_at and comment', () {
      final rating = ratingFromJson({'order_stars': 3, 'tags': null});
      expect(rating.orderStars, 3);
      expect(rating.comment, '');
      expect(rating.tags, isEmpty);
    });

    test('the real-API switch is off until the endpoints merge', () {
      // Flip `ratingApiBound` in app/repositories.dart when they do.
      expect(ratingApiBound, isFalse);
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
    });
  });
}
