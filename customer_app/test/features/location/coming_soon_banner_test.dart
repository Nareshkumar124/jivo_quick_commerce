import 'package:customer_app/app/theme.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_texts.dart';
import 'package:customer_app/features/location/presentation/coming_soon_banner.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_harness.dart';

/// "We're coming to your area soon!" (PM, 2026-11-26): the app's headline
/// and the server's message; no delivery area written into the app.
void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    String? message,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      harness(
        Theme(
          data: buildCustomerTheme(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ComingSoonBanner(message: message),
          ),
        ),
        textScaler: textScaler,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the headline and the server message', (tester) async {
    await pumpBanner(
      tester,
      message: 'Right now we deliver only in 110027, Delhi.',
    );
    expect(find.text("We're coming to your area soon!"), findsOneWidget);
    expect(
      find.text('Right now we deliver only in 110027, Delhi.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.delivery_dining), findsOneWidget);
    expect(
      tester.getSemantics(find.text("We're coming to your area soon!")),
      matchesSemantics(
        label: "We're coming to your area soon!",
        isHeader: true,
      ),
    );
  });

  testWidgets('no message from the server: a general line, no area', (
    tester,
  ) async {
    await pumpBanner(tester, message: '  ');
    expect(
      find.text(
        "We don't deliver to this location yet, but we're growing fast. "
        "We'll start here soon.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('110027'), findsNothing);
  });

  testWidgets('white text on the green card, full width, no overflow at '
      '2x text', (tester) async {
    await pumpBanner(
      tester,
      message: "We're not delivering here yet.",
      textScaler: const TextScaler.linear(2),
    );
    expect(tester.takeException(), isNull);
    final body = tester.widget<Text>(find.byKey(const Key('coming-soon-body')));
    expect(body.style?.color, Colors.white);
    final card = tester.getSize(find.byKey(const Key('coming-soon-banner')));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(card.width, screen.width - 32);
  });

  test('the NOT_SERVICEABLE blocker uses the server text, else the '
      'app\'s', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    CartSnapshot blocked(String message) => CartSnapshot(
      checkout: CheckoutStatus(
        canPlaceOrder: false,
        blockers: [
          CheckoutBlocker(
            code: CheckoutBlockerCode.notServiceable,
            message: message,
          ),
        ],
      ),
    );
    expect(
      checkoutBlockerText(l10n, blocked('We deliver only in 110027 for now.')),
      'We deliver only in 110027 for now.',
    );
    expect(
      checkoutBlockerText(l10n, blocked('')),
      "We don't deliver to this address from this store. Choose another "
      'address.',
    );
  });
}
