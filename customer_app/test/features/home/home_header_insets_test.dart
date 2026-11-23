import 'package:customer_app/app/bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

/// The status bar on a phone with a camera cut-out (logical px).
const _statusBar = 48.0;

void _phoneView(WidgetTester tester, {double top = _statusBar}) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top);
  tester.view.viewPadding = FakeViewPadding(top: top);
  addTearDown(tester.view.reset);
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  setUpAll(initializeFormatting);

  testWidgets('the home header starts below the status bar', (tester) async {
    _phoneView(tester);
    await TestApp(tokens: signedInTokens).pump(tester);

    expect(_top(tester, 'Deliver to'), greaterThanOrEqualTo(_statusBar));
    expect(
      _top(tester, 'Home · Flat 4B, MG Road, New Delhi'),
      greaterThan(_statusBar),
    );
    expect(
      tester.getTopLeft(find.byTooltip('Account').first).dy,
      greaterThanOrEqualTo(_statusBar),
    );
  });

  testWidgets('a status-bar inset that arrives after the first frame (cold '
      'start) moves the header down', (tester) async {
    _phoneView(tester, top: 0);
    await TestApp(tokens: signedInTokens).pump(tester);
    expect(_top(tester, 'Deliver to'), lessThan(_statusBar));

    tester.view.padding = const FakeViewPadding(top: _statusBar);
    tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
    await tester.pumpAndSettle();

    expect(_top(tester, 'Deliver to'), greaterThanOrEqualTo(_statusBar));
  });
}
