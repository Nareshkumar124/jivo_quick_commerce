import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/addresses/data/device_location.dart';
import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:customer_app/features/location/data/delivery_location_store.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:customer_app/features/location/presentation/map_picker_screen.dart';
import 'package:customer_app/features/location/presentation/store_closed_banner.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:customer_app/shared/network/store_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mappls_gl/mappls_gl.dart' show MapplsMapController;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

const mumbai = (lat: 19.0760, lng: 72.8777);

/// A stand-in for the Mappls platform view. With [errorCode] it reports a
/// map error after the first frame, like a failed authentication.
PinMapBuilder fakeMap({int? errorCode}) =>
    ({
      required GeoPoint initial,
      required void Function(MapplsMapController controller) onCreated,
      required VoidCallback onCameraIdle,
      required void Function(int code, String message) onError,
    }) => _FakeMap(
      onReady: errorCode == null
          ? null
          : () => onError(errorCode, 'Authentication failed'),
    );

class _FakeMap extends StatefulWidget {
  const _FakeMap({this.onReady});

  final VoidCallback? onReady;

  @override
  State<_FakeMap> createState() => _FakeMapState();
}

class _FakeMapState extends State<_FakeMap> {
  @override
  void initState() {
    super.initState();
    final onReady = widget.onReady;
    if (onReady != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
    }
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(key: Key('fake-map'), color: Colors.green);
}

Future<TestApp> openLocation(WidgetTester tester, {TestApp? app}) async {
  final testApp =
      app ?? TestApp(tokens: signedInTokens, deliveryLocation: null);
  await testApp.pump(tester);
  await tester.tap(
    find.widgetWithText(FilledButton, 'Select delivery location'),
  );
  await tester.pumpAndSettle();
  return testApp;
}

void main() {
  setUpAll(initializeFormatting);

  testWidgets('detecting the location selects it and opens home', (
    tester,
  ) async {
    final app = await openLocation(tester);
    await tester.tap(find.byKey(const Key('detect-location')));
    await tester.pumpAndSettle();

    expect(find.text('Delivery in 14 mins'), findsOneWidget);
    expect(find.text('Current location'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeliveryLocationStore.key), contains('28.6139'));
    expect(app.serviceability.checks, hasLength(1));
  });

  testWidgets('a denied permission explains itself and offers settings', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens, deliveryLocation: null);
    app.location.failure = LocationFailure.deniedForever;
    await openLocation(tester, app: app);
    await tester.tap(find.byKey(const Key('detect-location')));
    await tester.pumpAndSettle();

    expect(
      find.text('Location access is blocked for Jivo. Turn it on in Settings.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Open settings'));
    expect(app.location.settingsOpened, [LocationFailure.deniedForever]);
  });

  testWidgets('outside every area: not serviceable, then Notify me', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens, deliveryLocation: null);
    app.location.point = mumbai;
    await openLocation(tester, app: app);
    await tester.tap(find.byKey(const Key('detect-location')));
    await tester.pumpAndSettle();

    expect(find.text("We're not in your area yet"), findsOneWidget);
    await tester.tap(find.text('Notify me'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notify-done')), findsOneWidget);
    expect(app.serviceability.notified, [mumbai]);

    await tester.tap(find.text('Try another address'));
    await tester.pumpAndSettle();
    expect(find.text('Where should we deliver?'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeliveryLocationStore.key), isNull);
  });

  testWidgets('without a Maps key the picker falls back, never a map', (
    tester,
  ) async {
    await openLocation(tester);
    await tester.tap(find.byKey(const Key('pick-on-map')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-unavailable')), findsOneWidget);
    expect(find.text("Map isn't available"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Use current location'));
    await tester.pumpAndSettle();
    // The fix comes back as a pinned location and is selected.
    expect(find.text('Pinned location'), findsOneWidget);
    expect(find.text('Delivery in 14 mins'), findsOneWidget);
  });

  testWidgets('a map that fails to authenticate falls back', (tester) async {
    final app = TestApp(
      tokens: signedInTokens,
      deliveryLocation: null,
      mapsAvailable: true,
      extraOverrides: [
        pinMapBuilderProvider.overrideWithValue(fakeMap(errorCode: 401)),
      ],
    );
    await openLocation(tester, app: app);
    await tester.tap(find.byKey(const Key('pick-on-map')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-map')), findsNothing);
    expect(find.byKey(const Key('map-unavailable')), findsOneWidget);
    expect(find.text('Enter address manually'), findsOneWidget);
  });

  testWidgets('a working map previews the address and confirms the pin', (
    tester,
  ) async {
    final app = TestApp(
      tokens: signedInTokens,
      deliveryLocation: null,
      mapsAvailable: true,
      extraOverrides: [pinMapBuilderProvider.overrideWithValue(fakeMap())],
    );
    app.geocoder.address = 'Sector 14, Gurugram, Haryana 122001';
    await openLocation(tester, app: app);
    await tester.tap(find.byKey(const Key('pick-on-map')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(find.text('Sector 14, Gurugram, Haryana 122001'), findsOneWidget);
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(find.text('Delivery in 14 mins'), findsOneWidget);
    expect(
      find.text('Pinned location · Sector 14, Gurugram, Haryana 122001'),
      findsOneWidget,
    );
  });

  testWidgets('the fallback offers manual address entry', (tester) async {
    await openLocation(tester);
    await tester.tap(find.byKey(const Key('pick-on-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter address manually'));
    await tester.pumpAndSettle();
    expect(find.text('New address'), findsOneWidget);
  });

  testWidgets('switching to another store asks before clearing the cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = TestApp(tokens: signedInTokens);
    await app.addresses.create(
      const AddressInput(
        label: AddressLabel.work,
        house: 'Tower B',
        buildingStreet: 'Cyber City',
        city: 'Gurugram',
        state: 'Haryana',
        pincode: '122002',
        lat: 28.61,
        lng: 77.20,
      ),
    );
    await app.pump(tester);
    await tester.tap(find.byKey(const ValueKey('add-1001')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-bar')), findsOneWidget);

    app.serviceability.storeId = 2;
    Future<void> chooseWork() async {
      await tester.tap(find.byKey(const Key('home-address')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
    }

    await chooseWork();
    expect(find.text('Change delivery location?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20)); // close the sheet
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-bar')), findsOneWidget);

    await chooseWork();
    await tester.tap(find.text('Change and clear cart'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-bar')), findsNothing);
    expect(find.textContaining('Work · Tower B'), findsOneWidget);
    expect((await app.cart.load()).isEmpty, isTrue);
  });

  test('store-closed text: today, tomorrow, later (IST)', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // 10:00 pm IST on 2 Nov; opens 7:00 am IST.
    final now = DateTime.utc(2026, 11, 2, 16, 30);
    expect(
      storeClosedText(l10n, DateTime.utc(2026, 11, 2, 17), now: now),
      'Store closed. Opens at 10:30 pm. You can browse; checkout opens then.',
    );
    expect(
      storeClosedText(l10n, DateTime.utc(2026, 11, 3, 1, 30), now: now),
      contains('Opens tomorrow at 7:00 am'),
    );
    expect(
      storeClosedText(l10n, DateTime.utc(2026, 11, 5, 1, 30), now: now),
      contains('Opens at 5 Nov 2026, 7:00 am'),
    );
    expect(storeClosedText(l10n, null, now: now), l10n.storeClosed);
  });

  test('the delivery location survives a round trip; junk is ignored', () {
    const location = DeliveryLocation(
      point: (lat: 28.5, lng: 77.1),
      title: 'Home',
      subtitle: 'Flat 1',
      addressId: 7,
    );
    expect(DeliveryLocation.fromJson(location.toJson()), location);
    expect(DeliveryLocation.fromJson({'lat': 'x'}), isNull);
  });

  test('X-Store-Id goes on catalog and cart calls only', () {
    expect(storeHeaders('/api/v1/home/', 3), {'X-Store-Id': '3'});
    expect(storeHeaders('/api/v1/products/?category=oils', 3), {
      'X-Store-Id': '3',
    });
    expect(storeHeaders('/api/v1/search/suggest/', 3), {'X-Store-Id': '3'});
    expect(storeHeaders('/api/v1/cart/', 3), {'X-Store-Id': '3'});
    expect(storeHeaders('/api/v1/serviceability/', 3), isEmpty);
    expect(storeHeaders('/api/v1/me/', 3), isEmpty);
    expect(storeHeaders('/api/v1/home/', null), isEmpty);
  });
}
