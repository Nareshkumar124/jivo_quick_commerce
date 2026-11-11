import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/addresses/data/device_location.dart';
import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:customer_app/features/location/data/reverse_geocoder.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:customer_app/features/location/presentation/delivery_controller.dart';
import 'package:customer_app/features/location/presentation/map_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import '../location/location_test.dart' show fakeMap;

/// CA-07: the address pin comes first and is never silently the GPS fix.

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> openNewAddress(WidgetTester tester, TestApp app) async {
  tallView(tester);
  await app.pump(tester);
  await tester.tap(find.text('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Saved addresses'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add address'));
  await tester.pumpAndSettle();
}

Future<void> fillRequired(WidgetTester tester) async {
  for (final (key, text) in [
    ('house', 'Flat 4B'),
    ('street', 'Rose Apartments, MG Road'),
    ('city', 'New Delhi'),
    ('state', 'Delhi'),
    ('pincode', '110001'),
  ]) {
    await tester.enterText(find.byKey(Key('address-$key')), text);
  }
}

String fieldText(WidgetTester tester, String key) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(Key('address-$key')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

void main() {
  setUpAll(initializeFormatting);

  testWidgets('without a map: GPS only with a warning, and Save says what '
      'it waits for', (tester) async {
    final app = TestApp(tokens: signedInTokens);
    await openNewAddress(tester, app);

    expect(find.byKey(const Key('address-set-on-map')), findsNothing);
    expect(
      find.text('Use this only when you are at this address now.'),
      findsOneWidget,
    );
    expect(find.text('Set the delivery location first.'), findsOneWidget);

    await tester.tap(find.text('Use my current location'));
    await tester.pumpAndSettle();
    final pin = find.byKey(const Key('address-pin'));
    expect(
      find.descendant(of: pin, matching: find.text('Location captured')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: pin,
        matching: find.text('Pin at 28.61394, 77.20902'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('address-pin-needed')), findsNothing);
  });

  testWidgets('"Save this location" keeps the chosen pin (no GPS) and the '
      'new address becomes the delivery location', (tester) async {
    tallView(tester);
    const pinned = DeliveryLocation(
      point: (lat: 28.6201, lng: 77.2155),
      title: 'Pinned location',
      subtitle: 'Gate 2, Janpath, New Delhi',
    );
    final app = TestApp(tokens: signedInTokens, deliveryLocation: pinned);
    // The phone is somewhere else: a GPS read would fail the test.
    app.location.failure = LocationFailure.unavailable;
    await app.pump(tester);

    await tester.tap(find.byKey(const Key('home-address')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-this-location')));
    await tester.pumpAndSettle();

    final pin = find.byKey(const Key('address-pin'));
    expect(
      find.descendant(
        of: pin,
        matching: find.text('Gate 2, Janpath, New Delhi'),
      ),
      findsOneWidget,
    );
    await fillRequired(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = app.addresses.saved.single;
    expect((saved.lat, saved.lng), (28.6201, 77.2155));
    final delivery = containerOf(tester).read(deliveryProvider).location!;
    expect(delivery.addressId, app.addresses.items.single.id);
    expect(delivery.point, (lat: 28.6201, lng: 77.2155));
  });

  testWidgets('with a map: the pin is set on the map first and the form is '
      'prefilled from the geocoder', (tester) async {
    final app = TestApp(
      tokens: signedInTokens,
      mapsAvailable: true,
      extraOverrides: [pinMapBuilderProvider.overrideWithValue(fakeMap())],
    );
    app.geocoder.address = 'Connaught Place, New Delhi, Delhi 110001';
    app.geocoder.parts = const AddressParts(
      line: 'Connaught Place, New Delhi, Delhi 110001',
      area: 'Connaught Place',
      city: 'New Delhi',
      state: 'Delhi',
      pincode: '110001',
    );
    await openNewAddress(tester, app);
    expect(
      find.text('Set the delivery location on the map first.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('address-gps-warning')), findsNothing);

    await tester.tap(find.byKey(const Key('address-set-on-map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('address-pin')),
        matching: find.text('Connaught Place, New Delhi, Delhi 110001'),
      ),
      findsOneWidget,
    );
    expect(fieldText(tester, 'area'), 'Connaught Place');
    expect(fieldText(tester, 'city'), 'New Delhi');
    expect(fieldText(tester, 'state'), 'Delhi');
    expect(fieldText(tester, 'pincode'), '110001');
    expect(find.byKey(const Key('address-adjust-pin')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('address-house')), '12');
    await tester.enterText(
      find.byKey(const Key('address-street')),
      'Barakhamba Road',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final saved = app.addresses.saved.single;
    expect(
      (saved.lat, saved.lng),
      (
        FakeServiceabilityRepository.storeLocation.lat,
        FakeServiceabilityRepository.storeLocation.lng,
      ),
    );
    expect(saved.city, 'New Delhi');
  });

  testWidgets('editing shows the saved pin, not a new GPS fix', (tester) async {
    final app = TestApp(tokens: signedInTokens);
    app.location.failure = LocationFailure.unavailable;
    await app.addresses.create(
      const AddressInput(
        label: AddressLabel.home,
        house: 'Flat 4B',
        buildingStreet: 'Rose Apartments, MG Road',
        city: 'New Delhi',
        state: 'Delhi',
        pincode: '110001',
        lat: 28.6,
        lng: 77.2,
      ),
    );
    tallView(tester);
    await app.pump(tester);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved addresses'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final pin = find.byKey(const Key('address-pin'));
    expect(
      find.descendant(
        of: pin,
        matching: find.text('Pin at 28.60000, 77.20000'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pin, matching: find.textContaining('Flat 4B')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
  });
}
