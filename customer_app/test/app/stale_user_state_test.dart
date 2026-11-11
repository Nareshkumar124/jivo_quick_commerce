import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/addresses/domain/saved_address.dart';
import 'package:customer_app/features/addresses/presentation/address_controllers.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/presentation/otp_screen.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/data/fake_catalog_repository.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/location/data/delivery_location_store.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:customer_app/features/location/presentation/delivery_controller.dart';
import 'package:customer_app/features/search/presentation/search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/cart/cart_fixtures.dart';
import '../helpers/test_app.dart';

/// Records the `address_id` of every `GET /cart/`.
class AddressRecordingBackend extends FakeCommerceBackend {
  AddressRecordingBackend() : super(latency: Duration.zero);

  final loads = <int?>[];

  @override
  Future<CartSnapshot> load({int? addressId}) {
    loads.add(addressId);
    return super.load(addressId: addressId);
  }
}

/// The fake catalog, with "Previously bought" only for the first user.
class PerUserCatalog extends FakeCatalogRepository {
  PerUserCatalog() : super(latency: Duration.zero);

  bool withBuyAgain = true;

  @override
  Future<HomeFeed> home() async {
    final feed = await super.home();
    if (withBuyAgain) return feed;
    return HomeFeed(
      store: feed.store,
      banners: feed.banners,
      categories: feed.categories,
      collections: feed.collections,
    );
  }
}

const homeAddress = AddressInput(
  label: AddressLabel.home,
  house: 'Flat 4B',
  buildingStreet: 'Rose Apartments, MG Road',
  city: 'New Delhi',
  state: 'Delhi',
  pincode: '110001',
  lat: 28.6,
  lng: 77.2,
);

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

Future<void> putOilInCart(FakeCommerceBackend cart) => cart.setQuantity(
  101,
  1,
  preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
);

Future<void> openCart(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.cart);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeFormatting);

  testWidgets('deleting the selected address drops its id: the cart and '
      'checkout stop sending it', (tester) async {
    tallView(tester);
    const savedId = 100; // FakeAddressRepository's first id
    final backend = AddressRecordingBackend();
    final app = TestApp(
      tokens: signedInTokens,
      commerce: backend,
      deliveryLocation: const DeliveryLocation(
        point: FakeServiceabilityRepository.storeLocation,
        title: 'Home',
        subtitle: 'Flat 4B, MG Road, New Delhi',
        addressId: savedId,
      ),
    );
    final saved = await app.addresses.create(homeAddress);
    expect(saved.id, savedId);
    await putOilInCart(backend);
    await app.pump(tester);
    await openCart(tester);
    expect(backend.loads.last, saved.id);

    final container = containerOf(tester);
    await container.read(addressListProvider.notifier).delete(saved.id);
    await tester.pumpAndSettle();

    // Same place, no saved address: the server would refuse the deleted id
    // (VALIDATION_ERROR on every retry) and checkout asks for an address.
    final location = container.read(deliveryProvider).location!;
    expect(location.addressId, isNull);
    expect(location.point, FakeServiceabilityRepository.storeLocation);
    final stored = DeliveryLocationStore(await SharedPreferences.getInstance())
        .read();
    expect(stored!.addressId, isNull);
    expect(backend.loads.last, isNull);
  });

  testWidgets('switching from a saved address to a pin prices the cart for '
      'no address, not the last one', (tester) async {
    tallView(tester);
    final backend = AddressRecordingBackend();
    final app = TestApp(tokens: signedInTokens, commerce: backend);
    await putOilInCart(backend);
    await app.pump(tester);
    await openCart(tester);
    expect(backend.loads.last, testDeliveryLocation.addressId);

    final container = containerOf(tester);
    const pin = DeliveryLocation(
      point: FakeServiceabilityRepository.storeLocation,
      title: 'Pinned location',
    );
    final check = await container.read(deliveryProvider.notifier).check(pin);
    await container
        .read(deliveryProvider.notifier)
        .select(pin, check.serviceability);
    await tester.pumpAndSettle();

    expect(backend.loads.last, isNull);
  });

  testWidgets('sign-out forgets the delivery address, recent searches and '
      '"Previously bought": the next user sees none of them', (tester) async {
    tallView(tester);
    final catalog = PerUserCatalog();
    final app = TestApp(tokens: signedInTokens, catalogRepository: catalog);
    await app.pump(tester);
    expect(find.text('Home · Flat 4B, MG Road, New Delhi'), findsOneWidget);
    expect(find.text('Previously bought'), findsOneWidget);
    final container = containerOf(tester);
    await container.read(recentSearchesProvider.notifier).add('ghee');

    await app.session.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Log in or sign up'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeliveryLocationStore.key), isNull);
    expect(container.read(deliveryProvider).location, isNull);
    expect(container.read(recentSearchesProvider), isEmpty);

    // Another user signs in on the same phone.
    catalog.withBuyAgain = false;
    await loginToOtp(tester, '9000000001');
    await tester.enterText(
      find.byKey(OtpScreen.otpFieldKey),
      FakeAuthRepository.validOtp,
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Flat 4B'), findsNothing);
    expect(
      find.text("Choose a delivery location to see what's in stock near you."),
      findsOneWidget,
    );

    const location = DeliveryLocation(
      point: FakeServiceabilityRepository.storeLocation,
      title: 'Current location',
    );
    final delivery = container.read(deliveryProvider.notifier);
    final check = await delivery.check(location);
    await delivery.select(location, check.serviceability);
    await tester.pumpAndSettle();
    expect(find.text('Shop by category'), findsOneWidget);
    expect(find.text('Previously bought'), findsNothing);
  });
}
