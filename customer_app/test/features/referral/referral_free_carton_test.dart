import 'package:customer_app/app/bootstrap.dart' show initializeFormatting;
import 'package:customer_app/features/referral/data/referral_repository.dart';
import 'package:customer_app/features/referral/domain/referral.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import '../checkout/checkout_flow_test.dart' show appWithCart, openCheckout;
import 'referral_test.dart' show enterAndApply, pumpReferral;

/// ADR 0002: the referral reward is a free carton for both people. The
/// copy then says "1 free carton" and never a ₹ amount; the old ₹ reward
/// keeps its ₹ copy.
void main() {
  setUpAll(initializeFormatting);

  FakeReferralRepository freeCarton({ReferredBy? referredBy}) =>
      FakeReferralRepository(
        rewardType: ReferralRewardType.freeCarton,
        referredBy: referredBy,
      );

  testWidgets('free carton: headline and rule 3 name the carton, no ₹', (
    tester,
  ) async {
    await pumpReferral(tester, freeCarton());
    expect(
      find.text('Invite a friend. You and your friend each get 1 free carton'),
      findsOneWidget,
    );
    expect(
      find.text(
        'When their first order is delivered, you and your friend each get '
        '1 free carton. Use it within 30 days.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('₹'), findsNothing);
  });

  testWidgets('free carton: applying a code confirms the carton', (
    tester,
  ) async {
    await pumpReferral(tester, freeCarton());
    await enterAndApply(tester, 'AB3K7P');
    expect(
      find.text(
        'Code applied. You and your friend will each get 1 free carton '
        'after your first delivery.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'You and your friend will each get 1 free carton after your first '
        'delivery.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('free carton: a rewarded code points to Rewards', (tester) async {
    await pumpReferral(
      tester,
      freeCarton(
        referredBy: ReferredBy(
          codeMasked: 'AB**7P',
          status: ReferralStatus.rewarded,
          appliedAt: DateTime.utc(2026, 11, 13),
        ),
      ),
    );
    expect(
      find.text(
        'Your free carton is in Rewards. Tap Use there to add it to your cart.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('₹ reward: the old ₹ copy stays', (tester) async {
    await pumpReferral(tester, FakeReferralRepository());
    expect(find.text('Invite a friend, you both get ₹90 off'), findsOneWidget);
    expect(find.textContaining('free carton'), findsNothing);
  });

  testWidgets('free carton: the Account strip names the carton', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens);
    app.referral.rewardType = ReferralRewardType.freeCarton;
    await app.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(
      find.text('Invite a friend. You and your friend each get 1 free carton'),
      findsOneWidget,
    );
    expect(find.text('Invite a friend, you both get ₹90 off'), findsNothing);
  });

  testWidgets('checkout card: free carton and ₹ copy', (tester) async {
    final app = await appWithCart();
    app.referral.rewardType = ReferralRewardType.freeCarton;
    await openCheckout(tester, app);
    expect(
      find.text(
        'Enter it before you place this order. You and your friend each get '
        '1 free carton after it is delivered.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('checkout card: the ₹ reward keeps the ₹ copy', (tester) async {
    final app = await appWithCart();
    await openCheckout(tester, app);
    expect(
      find.text(
        "Enter it before you place this order. You and your friend each get "
        "₹90 off after it's delivered.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('referral-prompt')), findsOneWidget);
  });
}
