import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));
const form = Key('bank-form');

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  /// Documents done, no bank details: the status screen's next step.
  Future<void> openBank(WidgetTester tester) async {
    h.onboarding.seed(
      pendingPhone,
      pendingProfile(documents: allBicycleDocuments),
    );
    await h.signedInBefore(pendingPhone);
    await h.pump(tester);
    await tester.tap(byKey('status-next-step'));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await scrollTo(tester, byKey(key), listKey: form);
    await tester.enterText(byKey(key), text);
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(byKey('bank-save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the holder name is prefilled; an empty form shows the '
      'errors and saves nothing', (tester) async {
    await openBank(tester);

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(
      tester.widget<TextField>(byKey('bank-holder')).controller!.text,
      'Ravi Kumar',
    );
    expect(tester.getSize(byKey('bank-save')).height, greaterThanOrEqualTo(56));

    await save(tester);
    expect(find.text('This is required.'), findsNWidgets(3));
    expect(h.onboarding.calls, isNot(contains('saveBankAccount')));
  });

  testWidgets('mismatched account numbers and a bad IFSC are caught', (
    tester,
  ) async {
    await openBank(tester);
    await enter(tester, 'bank-account', '123456789012');
    await enter(tester, 'bank-account-confirm', '123456789013');
    await enter(tester, 'bank-ifsc', 'hdfc1001234');
    expect(
      tester.widget<TextField>(byKey('bank-ifsc')).controller!.text,
      'HDFC1001234',
      reason: 'upper-cased while typing',
    );
    await save(tester);

    expect(find.text("The account numbers don't match."), findsOneWidget);
    expect(
      find.text('Enter the 11-character IFSC, like HDFC0001234.'),
      findsOneWidget,
    );
    expect(h.onboarding.calls, isNot(contains('saveBankAccount')));
  });

  testWidgets('the account number is masked once typed; the confirm field '
      'takes no paste', (tester) async {
    await openBank(tester);
    await enter(tester, 'bank-account', '123456789012');
    expect(
      tester.widget<TextField>(byKey('bank-account')).obscureText,
      isFalse,
    );

    await enter(tester, 'bank-account-confirm', '1234');
    expect(tester.widget<TextField>(byKey('bank-account')).obscureText, isTrue);
    expect(find.text('Entered: XXXXXXXX9012'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains('123456789012'),
      ),
      findsNothing,
      reason: 'no label or helper shows the full number',
    );

    final confirm = tester.widget<TextField>(byKey('bank-account-confirm'));
    expect(confirm.enableInteractiveSelection, isFalse);
    expect(confirm.enableSuggestions, isFalse);
  });

  testWidgets('valid details: PUT /rider/bank-account/, then the status '
      'screen shows the masked account and the review', (tester) async {
    await openBank(tester);
    await enter(tester, 'bank-account', '123456789012');
    await enter(tester, 'bank-account-confirm', '123456789012');
    await enter(tester, 'bank-ifsc', 'HDFC0001234');
    await enter(tester, 'bank-upi', 'ravi@okhdfcbank');

    h.onboarding.failNext = const ApiError(code: ApiErrorCode.network);
    await save(tester);
    expect(byKey('bank-error'), findsOneWidget);

    await save(tester);
    expect(find.text('Bank details saved'), findsOneWidget);
    expect(find.text('Documents under review'), findsOneWidget);
    expect(find.text('Account XXXXXXXX9012'), findsOneWidget);
    final saved = h.onboarding.profileOf(pendingPhone)!.bankAccount!;
    expect(saved.accountNumberMasked, 'XXXXXXXX9012');
    expect(saved.ifsc, 'HDFC0001234');
    expect(saved.upiId, 'ravi@okhdfcbank');
  });

  testWidgets('rejected over the bank account: "Update bank details" shows '
      'the saved account masked', (tester) async {
    h.onboarding.seed(
      rejectedPhone,
      pendingProfile(
        documents: allBicycleDocuments,
        bank: bankSummary,
      ).copyWith(
        status: RiderStatusEnum.REJECTED,
        rejectionReason: 'The account holder name does not match your PAN.',
      ),
    );
    await h.signedInBefore(rejectedPhone);
    await h.pump(tester);

    expect(find.text('Documents not approved'), findsOneWidget);
    await tester.tap(byKey('status-fix'));
    await tester.pumpAndSettle();

    expect(byKey('bank-saved'), findsOneWidget);
    expect(
      find.text('Saved account XXXXXXXX9012 · HDFC0001234'),
      findsOneWidget,
    );
    expect(find.text('Step 3 of 3'), findsNothing);
  });
}
