import 'dart:async';

import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/launch_state.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/referral/data/referral_repository.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/location/presentation/delivery_controller.dart';
import 'package:customer_app/features/profile/domain/user_profile.dart';
import 'package:customer_app/features/referral/domain/referral.dart';
import 'package:customer_app/features/referral/presentation/referral_controller.dart';
import 'package:customer_app/features/referral/presentation/referral_screen.dart';
import 'package:customer_app/shared/storage/app_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';
import '../../app/stale_user_state_test.dart' show containerOf;
import '../checkout/checkout_flow_test.dart'
    show appWithCart, openCheckout, tallView;

/// The server's `Referral` examples (`account_referral_retrieve`).
Map<String, Object?> referralJson({
  bool canApplyCode = true,
  Map<String, Object?>? referredBy,
  int friendsJoined = 0,
  int friendsRewarded = 0,
}) => {
  'code': 'K7M2PQ',
  'share_message':
      'Use my code K7M2PQ on the Jivo app and we both get ₹90 off.',
  'is_enabled': true,
  'reward_amount': '90.00',
  'reward_validity_days': 30,
  'reward_min_order_value': '0.00',
  'can_apply_code': canApplyCode,
  'referred_by': referredBy,
  'friends_joined': friendsJoined,
  'friends_rewarded': friendsRewarded,
};

/// User 1 signed in, for screens pumped without the app (no launch state).
class _SignedInAsUser1 extends SignedInUserId {
  @override
  int? build() => 1;
}

/// The referral screen on [repo], with clipboard writes recorded.
Future<List<String>> pumpReferral(
  WidgetTester tester,
  FakeReferralRepository repo,
) async {
  tallView(tester);
  final clipboard = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      clipboard.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  await tester.pumpWidget(
    harness(
      const ReferralScreen(),
      overrides: [
        referralRepositoryProvider.overrideWithValue(repo),
        signedInUserIdProvider.overrideWith(_SignedInAsUser1.new),
        analyticsProvider.overrideWithValue(const NoopAnalyticsClient()),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return clipboard;
}

Future<void> enterAndApply(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(ReferralScreen.codeFieldKey), code);
  await tester.tap(find.byKey(ReferralScreen.applyKey));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeFormatting);

  group('referral screen', () {
    testWidgets('shows the code, Share, the rules and the counts', (
      tester,
    ) async {
      final repo = FakeReferralRepository(friendsJoined: 3, friendsRewarded: 1);
      await pumpReferral(tester, repo);

      expect(
        find.text('Invite a friend, you both get ₹90 off'),
        findsOneWidget,
      );
      expect(find.text('K7M2PQ'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Your referral code: K7M2PQ'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('referral-copy')), findsOneWidget);
      expect(find.text('Share invite'), findsOneWidget);
      expect(
        find.text('Share your code with a friend who is new to Jivo.'),
        findsOneWidget,
      );
      expect(
        find.text('They enter it before their first order.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'When their first order is delivered, you both get ₹90 off. '
          'Use it within 30 days.',
        ),
        findsOneWidget,
      );
      Finder stat(String key, String value) =>
          find.descendant(of: find.byKey(Key(key)), matching: find.text(value));
      expect(stat('referral-friends-joined', '3'), findsOneWidget);
      expect(stat('referral-friends-joined', 'Friends joined'), findsOneWidget);
      expect(stat('referral-rewards-earned', '1'), findsOneWidget);
      expect(stat('referral-rewards-earned', 'Rewards earned'), findsOneWidget);
      expect(find.byKey(const Key('referral-no-friends')), findsNothing);
    });

    testWidgets('Copy copies the code; Share copies the server message', (
      tester,
    ) async {
      final repo = FakeReferralRepository();
      final clipboard = await pumpReferral(tester, repo);

      await tester.tap(find.byKey(const Key('referral-copy')));
      await tester.pumpAndSettle();
      expect(clipboard.last, 'K7M2PQ');
      expect(find.text('Code K7M2PQ copied'), findsOneWidget);

      await tester.tap(find.byKey(const Key('referral-share')));
      await tester.pumpAndSettle();
      expect(clipboard.last, repo.info.shareMessage);
      expect(
        find.text(
          'Invite message copied. Paste it in WhatsApp or SMS to send it.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no friends yet: an empty-state line under the counts', (
      tester,
    ) async {
      await pumpReferral(
        tester,
        FakeReferralRepository(friendsJoined: 0, friendsRewarded: 0),
      );
      expect(
        find.text(
          'No friends have joined yet. Share your code to get started.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a minimum order for the reward is named in the rules', (
      tester,
    ) async {
      final repo = _MinOrderRepository();
      await pumpReferral(tester, repo);
      expect(
        find.textContaining('Valid on orders of ₹199 or more.'),
        findsOneWidget,
      );
    });

    testWidgets('applying a friend\'s code confirms the reward', (
      tester,
    ) async {
      final repo = FakeReferralRepository();
      await pumpReferral(tester, repo);
      expect(find.text('Have a referral code?'), findsOneWidget);

      await enterAndApply(tester, 'ab3k 7p');

      expect(repo.applied, ['ab3k 7p']);
      expect(
        find.text(
          'Code applied. You and your friend will each get ₹90 off after '
          'your first delivery.',
        ),
        findsOneWidget,
      );
      // The box is replaced by the status.
      expect(find.byKey(const Key('referral-apply-box')), findsNothing);
      expect(find.text('You joined with code AB**7P'), findsOneWidget);
      expect(
        find.text(
          'You and your friend will each get ₹90 off after your first '
          'delivery.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Apply with an empty field asks for the code; nothing sent', (
      tester,
    ) async {
      final repo = FakeReferralRepository();
      await pumpReferral(tester, repo);
      await enterAndApply(tester, '   ');
      expect(find.text("Enter your friend's code"), findsOneWidget);
      expect(repo.applied, isEmpty);
    });

    group('each refusal has its own message', () {
      Future<void> expectError(
        WidgetTester tester,
        FakeReferralRepository repo,
        String code,
        String message,
      ) async {
        await pumpReferral(tester, repo);
        await enterAndApply(tester, code);
        expect(find.text(message), findsOneWidget);
        // Still on the box, so the customer can fix the code.
        expect(find.byKey(const Key('referral-apply-box')), findsOneWidget);
      }

      testWidgets('REFERRAL_CODE_INVALID', (tester) async {
        await expectError(
          tester,
          FakeReferralRepository(),
          'ZZZZ99',
          "This referral code isn't valid. Check it and try again.",
        );
      });

      testWidgets('REFERRAL_SELF', (tester) async {
        await expectError(
          tester,
          FakeReferralRepository(),
          'k7m2pq',
          "That's your own code. Enter a friend's code instead.",
        );
      });

      testWidgets('REFERRAL_ALREADY_APPLIED', (tester) async {
        await expectError(
          tester,
          FakeReferralRepository()
            ..applyError = const ApiError(
              code: ApiErrorCode.referralAlreadyApplied,
              statusCode: 422,
            ),
          'AB3K7P',
          "You've already used a referral code. It can't be changed.",
        );
      });

      testWidgets('REFERRAL_NOT_ELIGIBLE (an order was placed)', (
        tester,
      ) async {
        await expectError(
          tester,
          FakeReferralRepository()
            ..applyError = const ApiError(
              code: ApiErrorCode.referralNotEligible,
              statusCode: 422,
              details: {'reason': 'HAS_ORDERS'},
            ),
          'AB3K7P',
          'Referral codes are only for new customers, before their first '
              'order.',
        );
      });

      testWidgets('REFERRAL_NOT_ELIGIBLE (program paused)', (tester) async {
        await expectError(
          tester,
          FakeReferralRepository()
            ..applyError = const ApiError(
              code: ApiErrorCode.referralNotEligible,
              statusCode: 422,
              details: {'reason': 'PROGRAM_OFF'},
            ),
          'AB3K7P',
          'Refer & earn is paused right now. Please try again later.',
        );
      });

      testWidgets('RATE_LIMITED names the wait', (tester) async {
        await expectError(
          tester,
          FakeReferralRepository()
            ..applyError = const ApiError(
              code: ApiErrorCode.rateLimited,
              statusCode: 429,
              details: {'retry_after_seconds': 120},
            ),
          'AB3K7P',
          'Too many attempts. Please try again in 2 minutes.',
        );
      });

      testWidgets('typing again clears the message', (tester) async {
        await expectError(
          tester,
          FakeReferralRepository(),
          'ZZZZ99',
          "This referral code isn't valid. Check it and try again.",
        );
        await tester.enterText(find.byKey(ReferralScreen.codeFieldKey), 'A');
        await tester.pump();
        expect(
          find.text("This referral code isn't valid. Check it and try again."),
          findsNothing,
        );
      });
    });

    testWidgets('no code box once referred; the status shows instead', (
      tester,
    ) async {
      final repo = FakeReferralRepository(
        referredBy: ReferredBy(
          codeMasked: 'AB**7P',
          status: ReferralStatus.rewarded,
          appliedAt: DateTime.utc(2026, 10, 2, 11, 40),
        ),
      );
      await pumpReferral(tester, repo);
      expect(find.byKey(const Key('referral-apply-box')), findsNothing);
      expect(find.text('You joined with code AB**7P'), findsOneWidget);
      expect(
        find.text(
          'Your ₹90 reward is in your coupons. Pick it under Apply coupon in '
          'your cart.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no code box after the first order', (tester) async {
      await pumpReferral(tester, FakeReferralRepository(hasOrders: true));
      expect(find.byKey(const Key('referral-apply-box')), findsNothing);
      expect(find.text('Have a referral code?'), findsNothing);
      expect(find.text('K7M2PQ'), findsOneWidget);
    });

    testWidgets('a paused program hides the code and Share', (tester) async {
      await pumpReferral(tester, FakeReferralRepository(isEnabled: false));
      expect(find.byKey(const Key('referral-paused')), findsOneWidget);
      expect(find.byKey(const Key('referral-code')), findsNothing);
      expect(find.byKey(const Key('referral-share')), findsNothing);
      expect(find.byKey(const Key('referral-apply-box')), findsNothing);
    });

    testWidgets('200% text on a narrow phone lays out without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          const ReferralScreen(),
          textScaler: const TextScaler.linear(2),
          overrides: [
            referralRepositoryProvider.overrideWithValue(
              FakeReferralRepository(),
            ),
            signedInUserIdProvider.overrideWith(_SignedInAsUser1.new),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(ReferralScreen.applyKey), findsOneWidget);
      final apply = tester.getSize(find.byKey(ReferralScreen.applyKey));
      expect(apply.height, greaterThanOrEqualTo(48));
    });

    testWidgets('a failed load shows Retry, which loads again', (tester) async {
      final repo = FakeReferralRepository()
        ..fetchError = const ApiError(code: ApiErrorCode.network);
      await pumpReferral(tester, repo);
      expect(find.text('Retry'), findsOneWidget);

      repo.fetchError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('K7M2PQ'), findsOneWidget);
    });
  });

  group('account row', () {
    Future<void> openAccount(TestApp app, WidgetTester tester) async {
      await app.pump(tester);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
    }

    testWidgets('names the reward and opens the referral screen', (
      tester,
    ) async {
      final app = TestApp(tokens: signedInTokens);
      await openAccount(app, tester);

      expect(find.text('Invite a friend, you both get ₹90 off'), findsOneWidget);
      expect(find.text("Got a friend's code? Enter it here"), findsOneWidget);

      await tester.tap(find.byKey(const Key('account-referral')));
      await tester.pumpAndSettle();
      expect(find.byType(ReferralScreen), findsOneWidget);
      expect(find.text('K7M2PQ'), findsOneWidget);
    });

    testWidgets('no "enter a code" line after the first order', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      app.referral.hasOrders = true;
      await openAccount(app, tester);
      expect(find.text('Invite a friend, you both get ₹90 off'), findsOneWidget);
      expect(find.byKey(const Key('referral-have-code')), findsNothing);
    });

    testWidgets('no "enter a code" line once referred', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      app.referral.referredBy = ReferredBy(
        codeMasked: 'AB**7P',
        status: ReferralStatus.pending,
        appliedAt: DateTime.utc(2026, 11, 13, 8, 15),
      );
      await openAccount(app, tester);
      expect(find.byKey(const Key('referral-have-code')), findsNothing);
    });

    testWidgets('a failed load still offers the row', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      app.referral.fetchError = const ApiError(code: ApiErrorCode.network);
      await openAccount(app, tester);
      expect(find.text('Refer a friend'), findsOneWidget);
    });

    testWidgets('applying from the account row hides the line', (tester) async {
      final app = TestApp(tokens: signedInTokens);
      await openAccount(app, tester);
      await tester.tap(find.byKey(const Key('account-referral')));
      await tester.pumpAndSettle();
      await enterAndApply(tester, 'JIVO90');
      expect(find.text('You joined with code JI**90'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('referral-have-code')), findsNothing);
    });
  });

  group('checkout card', () {
    testWidgets('a new customer sees it; Enter code opens the screen', (
      tester,
    ) async {
      final app = await appWithCart();
      await openCheckout(tester, app);
      expect(find.byKey(const Key('referral-prompt')), findsOneWidget);

      await tester.tap(find.byKey(const Key('referral-prompt-enter')));
      await tester.pumpAndSettle();
      expect(find.byType(ReferralScreen), findsOneWidget);
      await enterAndApply(tester, 'AB3K7P');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('referral-prompt')), findsNothing);
    });

    testWidgets('hidden for a customer who already ordered', (tester) async {
      final app = await appWithCart();
      app.referral.hasOrders = true;
      await openCheckout(tester, app);
      expect(find.byKey(const Key('referral-prompt')), findsNothing);
    });

    testWidgets('Close hides it and is remembered for this user', (
      tester,
    ) async {
      final app = await appWithCart();
      await openCheckout(tester, app);
      await tester.tap(find.byKey(const Key('referral-prompt-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('referral-prompt')), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(AppFlags.referralPromptDismissedKey(1)),
        isTrue,
        reason: 'the fake signed-in user has id 1',
      );
    });
  });

  group(
    'sign-out (any path) never carries referral state to the next user',
    () {
      for (final reason in SignOutReason.values) {
        testWidgets('${reason.name}: fresh referral load and card for user 2; '
            "user 1's closed flag kept", (tester) async {
          // User 1: closes the checkout card, then enters a friend's code.
          final app = await appWithCart();
          await openCheckout(tester, app);
          final container = containerOf(tester);
          expect(container.read(signedInUserIdProvider), 1);
          await tester.tap(find.byKey(const Key('referral-prompt-close')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('referral-prompt')), findsNothing);
          await container.read(referralApplyProvider.notifier).apply('AB3K7P');
          await tester.pumpAndSettle();
          expect(
            container.read(currentReferralProvider).value!.canApplyCode,
            isFalse,
          );
          expect(
            container.read(currentReferralProvider).value!.referredBy,
            isNotNull,
          );
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(AppFlags.referralPromptDismissedKey(1)), isTrue);

          // Signed out: logout and account deletion call signOut() (user
          // requested); a rejected refresh token signs out as expired.
          // Both run the same hooks.
          final fetchesBefore = app.referral.fetches;
          await app.session.signOut(reason: reason);
          await tester.pumpAndSettle();
          expect(find.text('Log in or sign up'), findsOneWidget);
          expect(container.read(signedInUserIdProvider), isNull);
          expect(
            app.referral.fetches,
            fetchesBefore,
            reason: 'no referral request without a token',
          );

          // User 2 (a new customer for the server) signs in on this phone,
          // the way the OTP flow does: the user first, then the tokens.
          app.referral.referredBy = null;
          final user2Load = Completer<void>();
          app.referral.fetchGate = user2Load.future;
          container
              .read(launchStateProvider)
              .setUser(
                const UserProfile(
                  id: 2,
                  phone: '+919000000002',
                  name: 'Second Customer',
                  isProfileComplete: true,
                ),
              );
          await app.session.signIn(
            const AuthTokens(access: 'a2', refresh: 'r2'),
          );
          await tester.pumpAndSettle();
          expect(container.read(signedInUserIdProvider), 2);

          // Checkout again (the location went with user 1).
          final delivery = container.read(deliveryProvider.notifier);
          final check = await delivery.check(testDeliveryLocation);
          await delivery.select(testDeliveryLocation, check.serviceability);
          await tester.pumpAndSettle();
          final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
          router.push(Routes.cart);
          await tester.pumpAndSettle();
          router.push(Routes.checkout);
          await tester.pumpAndSettle();

          // While user 2's referral loads, nothing of user 1's shows.
          expect(container.read(currentReferralProvider).value, isNull);
          expect(find.byKey(const Key('referral-prompt')), findsNothing);
          app.referral.fetchGate = null;
          user2Load.complete();
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('referral-prompt')), findsOneWidget);
          expect(app.referral.fetches, greaterThan(fetchesBefore));
          final info = container.read(currentReferralProvider).value!;
          expect(info.canApplyCode, isTrue);
          expect(info.referredBy, isNull);
          expect(prefs.getBool(AppFlags.referralPromptDismissedKey(1)), isTrue);
          expect(prefs.getBool(AppFlags.referralPromptDismissedKey(2)), isNull);
        });
      }

      testWidgets('an apply answer that arrives after sign-out is dropped', (
        tester,
      ) async {
        final app = TestApp(tokens: signedInTokens);
        await app.pump(tester);
        final container = containerOf(tester);
        final sub = container.listen(referralApplyProvider, (_, _) {});
        addTearDown(sub.close);
        await container.read(referralProvider(1).future);

        final slow = Completer<void>();
        app.referral.applyGate = slow.future;
        final applying = container
            .read(referralApplyProvider.notifier)
            .apply('AB3K7P');
        await app.session.signOut();
        await tester.pumpAndSettle();
        slow.complete();
        await applying;
        await tester.pumpAndSettle();

        // Nobody signed in: nothing to show, and nothing crashed.
        expect(container.read(currentReferralProvider).value, isNull);
        expect(app.referral.applied, ['AB3K7P']);
      });
    },
  );

  group('API repository', () {
    test('maps GET /account/referral/', () async {
      final http = FakeHttp(
        (_) => (
          200,
          referralJson(
            canApplyCode: false,
            referredBy: {
              'code_masked': 'AB**7P',
              'status': 'PENDING',
              'applied_at': '2026-11-13T08:15:00Z',
            },
            friendsJoined: 3,
            friendsRewarded: 1,
          ),
        ),
      );
      final info = await ApiReferralRepository(http.api()).fetch();

      expect(http.requests.single.path, endsWith('/api/v1/account/referral/'));
      expect(info.code, 'K7M2PQ');
      expect(info.rewardAmount, '90.00');
      expect(info.rewardValidityDays, 30);
      expect(info.canApplyCode, isFalse);
      expect(info.friendsJoined, 3);
      expect(info.friendsRewarded, 1);
      expect(
        info.referredBy,
        ReferredBy(
          codeMasked: 'AB**7P',
          status: ReferralStatus.pending,
          appliedAt: DateTime.utc(2026, 11, 13, 8, 15),
        ),
      );
    });

    test('maps every referral status, unknown ones too', () async {
      for (final (wire, status) in [
        ('PENDING', ReferralStatus.pending),
        ('REWARDED', ReferralStatus.rewarded),
        ('VOID', ReferralStatus.noReward),
        ('SOMETHING_NEW', ReferralStatus.unknown),
      ]) {
        final http = FakeHttp(
          (_) => (
            200,
            referralJson(
              canApplyCode: false,
              referredBy: {
                'code_masked': 'AB**7P',
                'status': wire,
                'applied_at': '2026-11-13T08:15:00Z',
              },
            ),
          ),
        );
        final info = await ApiReferralRepository(http.api()).fetch();
        expect(info.referredBy!.status, status, reason: wire);
      }
    });

    test('POST /account/referral/apply/ sends the code', () async {
      final http = FakeHttp((_) => (200, referralJson(canApplyCode: false)));
      final info = await ApiReferralRepository(http.api()).apply(' ab3k 7p ');

      final request = http.requests.single;
      expect(request.method, 'POST');
      expect(request.path, endsWith('/api/v1/account/referral/apply/'));
      expect(http.body(0), {'code': 'ab3k 7p'});
      expect(info.canApplyCode, isFalse);
    });

    test('a 422 refusal becomes the matching ApiError', () async {
      final http = FakeHttp(
        (_) => (
          422,
          {
            'error': {
              'code': 'REFERRAL_NOT_ELIGIBLE',
              'message': 'The referral program is paused right now.',
              'details': {'reason': 'PROGRAM_OFF'},
            },
          },
        ),
      );
      await expectLater(
        ApiReferralRepository(http.api()).apply('AB3K7P'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', ApiErrorCode.referralNotEligible)
              .having((e) => e.reason, 'reason', 'PROGRAM_OFF')
              .having((e) => e.statusCode, 'status', 422),
        ),
      );
    });
  });

  group('fake repository (FAKE_API builds)', () {
    test('follows the server order of checks', () async {
      Future<ApiErrorCode?> codeOf(
        FakeReferralRepository repo,
        String code,
      ) async {
        try {
          await repo.apply(code);
          return null;
        } on ApiError catch (e) {
          return e.code;
        }
      }

      expect(
        await codeOf(FakeReferralRepository(isEnabled: false), 'K7M2PQ'),
        ApiErrorCode.referralNotEligible,
      );
      expect(
        await codeOf(FakeReferralRepository(hasOrders: true), 'ZZZZ'),
        ApiErrorCode.referralNotEligible,
      );
      expect(
        await codeOf(FakeReferralRepository(), 'ZZZZ'),
        ApiErrorCode.referralCodeInvalid,
      );
      expect(
        await codeOf(FakeReferralRepository(), 'k7m2 pq'),
        ApiErrorCode.referralSelf,
      );
      final repo = FakeReferralRepository();
      expect(await codeOf(repo, 'ab3k7p'), isNull);
      expect(repo.info.canApplyCode, isFalse);
      expect(repo.info.referredBy!.codeMasked, 'AB**7P');
      expect(await codeOf(repo, 'JIVO90'), ApiErrorCode.referralAlreadyApplied);
    });
  });
}

/// A reward that needs a minimum order (`reward_min_order_value`).
class _MinOrderRepository extends FakeReferralRepository {
  @override
  ReferralInfo get info {
    final base = super.info;
    return ReferralInfo(
      code: base.code,
      shareMessage: base.shareMessage,
      isEnabled: base.isEnabled,
      rewardAmount: base.rewardAmount,
      rewardValidityDays: base.rewardValidityDays,
      rewardMinOrderValue: '199.00',
      canApplyCode: base.canApplyCode,
      referredBy: base.referredBy,
      friendsJoined: base.friendsJoined,
      friendsRewarded: base.friendsRewarded,
    );
  }
}
