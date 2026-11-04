import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/rating/data/rating_repository.dart';
import 'package:customer_app/features/rating/domain/order_rating.dart';
import 'package:customer_app/features/rating/presentation/rating_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

/// Order rating (`03 §2.10`, P7 lookahead on fakes).
void main() {
  group('RatingTag', () {
    test('4–5 stars offer the positive tags, 1–3 the negative', () {
      expect(RatingTag.forStars(0), isEmpty);
      expect(RatingTag.forStars(5).every((t) => t.positive), isTrue);
      expect(RatingTag.forStars(2).every((t) => !t.positive), isTrue);
      expect(RatingTag.fromWire('ON_TIME'), RatingTag.onTime);
      expect(RatingTag.fromWire('NOPE'), isNull);
    });
  });

  group('RatingFormController', () {
    late FakeRatingRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = FakeRatingRepository();
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [ratingRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    test('cannot submit without order stars', () async {
      final sub = container.listen(ratingFormProvider(1), (_, _) {});
      addTearDown(sub.close);
      expect(container.read(ratingFormProvider(1)).canSubmit, isFalse);
      expect(
        await container.read(ratingFormProvider(1).notifier).submit('x'),
        isNull,
      );
      expect(repo.submissions, isEmpty);
    });

    test('changing stars drops tags that no longer fit', () {
      final sub = container.listen(ratingFormProvider(1), (_, _) {});
      addTearDown(sub.close);
      final form = container.read(ratingFormProvider(1).notifier)
        ..setOrderStars(2)
        ..toggleTag(RatingTag.lateDelivery)
        ..setOrderStars(1);
      expect(container.read(ratingFormProvider(1)).tags, {
        RatingTag.lateDelivery,
      });
      form.setOrderStars(5);
      expect(container.read(ratingFormProvider(1)).tags, isEmpty);
    });

    test('submits stars, tags, rider stars and the trimmed comment', () async {
      final sub = container.listen(ratingFormProvider(4), (_, _) {});
      addTearDown(sub.close);
      final form = container.read(ratingFormProvider(4).notifier)
        ..setOrderStars(5)
        ..toggleTag(RatingTag.onTime)
        ..setRiderStars(4);
      final rating = await form.submit('  Great  ');
      expect(rating!.orderStars, 5);
      final (orderId, input) = repo.submissions.single;
      expect(orderId, 4);
      expect(input.riderStars, 4);
      expect(input.tags, {RatingTag.onTime});
      expect(input.comment, 'Great');
      expect(await container.read(orderRatingProvider(4).future), isNotNull);
    });

    test('a failure is kept for the screen and the form can retry', () async {
      final sub = container.listen(ratingFormProvider(1), (_, _) {});
      addTearDown(sub.close);
      repo.failNext = const ApiError(code: ApiErrorCode.network);
      final form = container.read(ratingFormProvider(1).notifier)
        ..setOrderStars(3);
      expect(await form.submit(''), isNull);
      final state = container.read(ratingFormProvider(1));
      expect(state.error, isA<ApiError>());
      expect(state.submitting, isFalse);
      expect(await form.submit(''), isNotNull);
    });
  });

  group('rate screen', () {
    late FakeCommerceBackend backend;
    late FakeRatingRepository ratings;

    setUp(() {
      backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
      ratings = FakeRatingRepository();
    });

    TestApp app() => TestApp(
      tokens: signedInTokens,
      commerce: backend,
      extraOverrides: [
        ratingAvailableProvider.overrideWithValue(true),
        ratingRepositoryProvider.overrideWithValue(ratings),
      ],
    );

    Future<int> openDelivered(WidgetTester tester) async {
      await app().pump(tester);
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.delivered)
          .id;
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-orders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('order-$id')));
      await tester.pumpAndSettle();
      return id;
    }

    testWidgets('delivered order: tap a star, add a tag, submit, then the '
        'detail shows the rating', (tester) async {
      final id = await openDelivered(tester);
      expect(find.byKey(const Key('rate-order-card')), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('rate-order-card')),
          matching: find.byKey(const Key('star-4')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rate-order')), findsOneWidget);
      // Four stars preselected: the positive tags are offered.
      expect(find.text('What went well?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tag-WELL_PACKED')));
      await tester.enterText(
        find.byKey(const Key('rating-comment')),
        'Quick delivery',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('submit-rating')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('rate-order')),
          matching: find.byType(Scrollable),
        ).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit-rating')));
      await tester.pumpAndSettle();

      final (orderId, input) = ratings.submissions.single;
      expect(orderId, id);
      expect(input.orderStars, 4);
      expect(input.tags, {RatingTag.wellPacked});
      expect(input.comment, 'Quick delivery');
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
      expect(find.byKey(const Key('order-rated')), findsOneWidget);
      expect(find.text('You rated this order 4 stars'), findsOneWidget);
    });

    testWidgets('stars are 48 dp targets with labels', (tester) async {
      await openDelivered(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('rate-order-card')),
          matching: find.byKey(const Key('star-2')),
        ),
      );
      await tester.pumpAndSettle();
      final star = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('order-stars')),
          matching: find.byKey(const Key('star-1')),
        ),
      );
      expect(star.width, greaterThanOrEqualTo(48));
      expect(star.height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('1 star'), findsNWidgets(2));
      expect(find.text('What went wrong?'), findsOneWidget);
    });

    testWidgets('not delivered: no rating card', (tester) async {
      await app().pump(tester);
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.packing)
          .id;
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-orders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('order-$id')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rate-order-card')), findsNothing);
    });
  });
}
