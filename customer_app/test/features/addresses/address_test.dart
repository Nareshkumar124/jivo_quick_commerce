import 'package:customer_app/features/addresses/data/address_repository.dart';
import 'package:customer_app/features/addresses/data/device_location.dart';
import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

const home = AddressInput(
  label: AddressLabel.home,
  house: 'Flat 4B',
  buildingStreet: 'Rose Apartments, MG Road',
  city: 'New Delhi',
  state: 'Delhi',
  pincode: '110001',
  lat: 28.6,
  lng: 77.2,
);

Future<void> openAddresses(TestApp app, WidgetTester tester) async {
  // Tall enough for the whole address form, so no scrolling is needed.
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await app.pump(tester);
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Saved addresses'));
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key('address-$key')), text);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillRequired(WidgetTester tester) async {
  await type(tester, 'house', 'Flat 4B');
  await type(tester, 'street', 'Rose Apartments, MG Road');
  await type(tester, 'city', 'New Delhi');
  await type(tester, 'state', 'Delhi');
  await type(tester, 'pincode', '110001');
}

void main() {
  testWidgets('empty list, then add an address with the device location', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens);
    await openAddresses(app, tester);
    expect(find.text('No saved addresses yet.'), findsOneWidget);

    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'needs a location first',
    );

    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();
    expect(find.text('Location captured'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await fillRequired(tester);
    await tapVisible(tester, save);

    final saved = app.addresses.saved.single;
    expect(saved.label, AddressLabel.work);
    expect((saved.lat, saved.lng), (28.613939, 77.209023));
    expect(saved.pincode, '110001');
    expect(find.text('Address saved.'), findsOneWidget);
    expect(
      find.text('Default'),
      findsOneWidget,
      reason: 'the first address becomes the default',
    );
  });

  testWidgets('validates required fields, PIN code and receiver phone', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens);
    await openAddresses(app, tester);
    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    await type(tester, 'pincode', '012345');
    await type(tester, 'rphone', '12345');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save'));

    expect(app.addresses.saved, isEmpty);
    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
    expect(find.text('This field is required.'), findsWidgets);
    expect(find.text('Enter a valid 6-digit PIN code.'), findsOneWidget);
  });

  testWidgets('a denied permission explains itself and offers settings', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens);
    app.location.failure = LocationFailure.deniedForever;
    await openAddresses(app, tester);
    await tester.tap(find.text('Add address'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Location access is blocked for Jivo. Turn it on in Settings.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open settings'));
    expect(app.location.settingsOpened, [LocationFailure.deniedForever]);
  });

  testWidgets('set default and delete from the list', (tester) async {
    final app = TestApp(tokens: signedInTokens);
    await app.addresses.create(home);
    await app.addresses.create(
      const AddressInput(
        label: AddressLabel.other,
        customLabel: "Mom's place",
        house: '12',
        buildingStreet: 'Lake Road',
        city: 'Kolkata',
        state: 'West Bengal',
        pincode: '700029',
        lat: 22.5,
        lng: 88.3,
      ),
    );
    await openAddresses(app, tester);
    expect(find.text("Mom's place"), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as default'));
    await tester.pumpAndSettle();
    expect(
      app.addresses.items.firstWhere((a) => a.isDefault).input.customLabel,
      "Mom's place",
    );

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(app.addresses.items, hasLength(1));
  });

  test('coordinates are rounded to the 6 places the backend stores', () {
    expect(roundCoordinate(28.61393912345), 28.613939);
    expect(roundCoordinate(-77.2090236), -77.209024);
  });
}
