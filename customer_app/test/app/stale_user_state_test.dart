import 'dart:async';

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
import 'package:customer_app/features/catalog/presentation/catalog_controllers.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/location/data/delivery_location_store.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:customer_app/features/location/presentation/delivery_controller.dart';
import 'package:customer_app/features/rewards/domain/reward.dart';
import 'package:customer_app/features/rewards/presentation/rewards_providers.dart';
import 'package:jivo_core/jivo_core.dart' show ApiError, ApiErrorCode;
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
  tester.view.physicalSize = const Size(800, 7000);
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
    final container = containerOf(tester);
    // The rail is hidden on Home (2026-11-25), so check the feed itself.
    expect(container.read(homeFeedProvider).value!.buyAgain, isNotEmpty);
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
    expect(find.text('All products'), findsOneWidget);
    expect(container.read(homeFeedProvider).value!.buyAgain, isEmpty);
  });

  testWidgets('sign-out: the next user never sees the previous user\'s '
      'rewards (ADR 0002)', (tester) async {
    tallView(tester);
    RewardsSummary rewardsOf(String code) => RewardsSummary(
      available: [
        Reward(
          code: code,
          title: '1 free carton',
          source: RewardSource.welcome,
          status: RewardStatus.available,
        ),
      ],
    );
    final app = TestApp(tokens: signedInTokens);
    app.rewards.summary = rewardsOf('USER-A-1FC');
    await app.pump(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.myCoupons);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reward-USER-A-1FC')), findsOneWidget);
    final container = containerOf(tester);

    await app.session.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Log in or sign up'), findsOneWidget);
    // Signed out: no rewards and no request for them.
    final fetches = app.rewards.fetches;
    final sub = container.listen(rewardsProvider, (_, _) {});
    expect(ApiError.from(sub.read().error!).code, ApiErrorCode.authRequired);
    sub.close();
    expect(app.rewards.fetches, fetches);

    // User B signs in; their rewards load slowly: user A's never show.
    app.rewards.summary = rewardsOf('USER-B-1FC');
    final gate = Completer<void>();
    app.rewards.gate = gate.future;
    await loginToOtp(tester, '9000000001');
    await tester.enterText(
      find.byKey(OtpScreen.otpFieldKey),
      FakeAuthRepository.validOtp,
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.myCoupons);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('reward-USER-A-1FC')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reward-USER-B-1FC')), findsOneWidget);
    expect(find.byKey(const ValueKey('reward-USER-A-1FC')), findsNothing);
  });
}
