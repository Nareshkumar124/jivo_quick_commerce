// Phase 2 critical flow (T-209): log in, detect the delivery location
// (serviceability), home with the store's products, a product page, search,
// add to the in-memory cart (dev flavor only until the Phase 3 cart API).
//
// Against the real backend (the default; Android emulator, dev flavor):
//   flutter test integration_test/browse_flow_test.dart --flavor dev \
//     -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8001
// The device location is faked at Sector 14, Gurugram (28.4595, 77.0266),
// which the seeded store "Jivo Sector 14, Gurugram" (id 1) serves. For other
// data pass TEST_LAT / TEST_LNG / TEST_STORE_ID / SEARCH_TERM / TEST_PHONE.
//
// On fakes (no backend): add --dart-define=FAKE_API=true. The output's
// `BROWSE mode=` line says which one ran.
//
// The map picker has its own on-device check (map_picker_test.dart); here
// the build reports no map, so "Use current location" selects the fix
// directly.
import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/addresses/data/device_location.dart';
import 'package:customer_app/features/auth/presentation/login_screen.dart';
import 'package:customer_app/features/auth/presentation/otp_screen.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/catalog/presentation/catalog_controllers.dart';
import 'package:customer_app/features/home/presentation/banner_carousel.dart';
import 'package:customer_app/features/location/data/maps_availability.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/location/presentation/delivery_controller.dart';
import 'package:customer_app/features/profile/presentation/profile_form.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

const phoneDigits = String.fromEnvironment(
  'TEST_PHONE',
  defaultValue: '9000000001',
);
const otp = String.fromEnvironment('TEST_OTP', defaultValue: '123456');
const searchTerm = String.fromEnvironment('SEARCH_TERM', defaultValue: 'olive');
const expectedStoreId = int.fromEnvironment('TEST_STORE_ID', defaultValue: 1);
const _lat = String.fromEnvironment('TEST_LAT', defaultValue: '28.4595');
const _lng = String.fromEnvironment('TEST_LNG', defaultValue: '77.0266');

/// Records what went over the wire, after every other interceptor.
class _Recorder extends Interceptor {
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add(options);
    handler.next(options);
  }
}

void log(String line) => debugPrint('BROWSE $line');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'browse: location, home, product, search, add to cart',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      final env = AppEnv.fromEnvironment(Flavor.dev);
      final fake = env.useFakeApi;
      log('mode=${fake ? 'fake' : 'real'} api=${env.apiBaseUrl}');
      // The fakes serve one store in central New Delhi.
      final point = fake
          ? FakeServiceabilityRepository.storeLocation
          : (lat: double.parse(_lat), lng: double.parse(_lng));

      final clientInfo = await ClientInfo.fromPlatform(
        appName: customerAppName,
      );
      await initializeFormatting();
      // In-memory session and flags: always starts at login.
      SharedPreferences.setMockInitialValues({
        'installed': true,
        'onboarding_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final session = createSession(
        env: env,
        clientInfo: clientInfo,
        store: InMemoryTokenStore(),
      );
      await session.restore();

      await tester.pumpWidget(
        customerAppRoot(
          env: env,
          clientInfo: clientInfo,
          session: session,
          signals: AppControlSignals(),
          prefs: prefs,
          overrides: [
            otpAutofillProvider.overrideWithValue(FakeOtpAutofill()),
            deviceLocationProvider.overrideWithValue(
              FakeDeviceLocation(point: point),
            ),
            mapsAvailabilityProvider.overrideWithValue(
              const FakeMapsAvailability(),
            ),
            // A still home lets the frames settle.
            bannerAutoScrollProvider.overrideWithValue(null),
          ],
        ),
      );

      // 1. Log in (an existing test customer goes straight home).
      await pumpUntilFound(tester, find.byKey(LoginScreen.phoneFieldKey));
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(LoginScreen.phoneFieldKey)),
      );
      final recorder = _Recorder();
      container.read(dioProvider).interceptors.add(recorder);

      await tester.enterText(
        find.byKey(LoginScreen.phoneFieldKey),
        phoneDigits,
      );
      await tester.tap(find.text('Get OTP'));
      await pumpUntilFound(tester, find.byKey(OtpScreen.otpFieldKey));
      await tester.enterText(find.byKey(OtpScreen.otpFieldKey), otp);
      final home = find.byKey(const Key('home-screen'));
      final profile = find.byKey(ProfileForm.nameFieldKey);
      await pumpUntilFound(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w.key == const Key('home-screen') ||
              w.key == ProfileForm.nameFieldKey,
        ),
      );
      if (profile.evaluate().isNotEmpty) {
        await tester.enterText(profile, 'Browse Tester');
        await tester.tap(find.text('Continue'));
        await pumpUntilFound(tester, home);
      }
      expect(session.isSignedIn, isTrue);

      // 2. Serviceability: detect the location from home.
      await pumpUntilFound(tester, find.text('Select delivery location'));
      await tester.tap(find.text('Select delivery location'));
      await pumpUntilFound(tester, find.byKey(const Key('detect-location')));
      await tester.tap(find.byKey(const Key('detect-location')));
      final tiles = byKeyPrefix('tile-');
      await pumpUntilFound(tester, tiles);

      final delivery = container.read(deliveryProvider);
      log(
        'serviceability point=${point.lat},${point.lng} '
        'store=${delivery.storeId} "${delivery.store?.name}" '
        'eta=${delivery.serviceability?.etaMinutes}',
      );
      expect(delivery.serviceability?.serviceable, isTrue);
      expect(delivery.storeId, expectedStoreId);

      // 3. Home shows the store's products.
      final feed = container.read(homeFeedProvider).requireValue;
      final homeProducts = [
        for (final c in feed.collections) ...c.items,
        ...feed.buyAgain,
      ];
      log(
        'home store="${feed.store?.name}" banners=${feed.banners.length} '
        'categories=${feed.categories.length} '
        'collections=${[for (final c in feed.collections) '${c.slug}:${c.items.length}']} '
        'tiles_on_screen=${tiles.evaluate().length}',
      );
      expect(homeProducts, isNotEmpty);

      // 4. Open the first product on home.
      final first = tester.widget(tiles.first).key! as ValueKey<String>;
      final opened = homeProducts.firstWhere(
        (p) => 'tile-${p.id}' == first.value,
      );
      await tester.ensureVisible(tiles.first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: tiles.first, matching: find.text(opened.name)),
      );
      await pumpUntilFound(tester, byKeyPrefix('pdp-'));
      final detail = await container.read(
        productDetailProvider(opened.slug).future,
      );
      log(
        'product slug=${detail.slug} "${detail.name}" '
        'variants=${[for (final v in detail.variants) '${v.id}:${v.name}:${v.sellingPrice}:${v.stockStatus.name}']}',
      );
      expect(detail.slug, opened.slug);
      expect(find.text(detail.name), findsWidgets);

      // 5. Search from home.
      await tester.pageBack();
      await pumpUntilFound(tester, find.byKey(const Key('home-search')));
      await tester.tap(find.byKey(const Key('home-search')));
      await pumpUntilFound(tester, find.byKey(const Key('search-field')));
      await tester.enterText(find.byKey(const Key('search-field')), searchTerm);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await pumpUntilFound(tester, find.byKey(const Key('product-grid')));
      await pumpUntilFound(tester, tiles);
      final results = container
          .read(pagedProductsProvider(const SearchQuery(searchTerm)))
          .requireValue
          .items;
      log(
        'search q="$searchTerm" results=${results.length} '
        '${[for (final p in results) p.name]}',
      );
      expect(results, isNotEmpty);

      // 6. Add a single-variant, in-stock result to the in-memory cart.
      final pick = results.firstWhere(
        (p) => p.variants.length == 1 && p.defaultVariant.inStock,
        orElse: () => fail('no single-variant in-stock result'),
      );
      final variant = pick.defaultVariant;
      final add = find.byKey(ValueKey('add-${variant.id}'));
      await tester.scrollUntilVisible(
        add,
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('product-grid')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(add);
      await pumpUntilFound(tester, find.byKey(const Key('cart-bar')));
      final cart = container.read(cartProvider).snapshot;
      log(
        'cart added "${pick.name}" variant=${variant.id} ${variant.name} '
        'items=${cart.itemCount} qty=${cart.quantityOf(variant.id)}',
      );
      expect(cart.quantityOf(variant.id), 1);
      expect(find.byKey(ValueKey('qty-${variant.id}')), findsOneWidget);

      // Every catalog call carried the serving store; serviceability none.
      final calls = [
        for (final r in recorder.requests)
          if (r.path.startsWith('/api/v1/')) r,
      ];
      log(
        'requests ${[for (final r in calls) '${r.method} ${r.path} store=${r.headers['X-Store-Id']}']}',
      );
      if (!fake) {
        const catalog = ['/home/', '/categories/', '/products/', '/search/'];
        final scoped = calls.where(
          (r) => catalog.any((p) => r.path.startsWith('/api/v1$p')),
        );
        expect({
          for (final r in scoped) r.path.split('/')[3],
        }, containsAll(['home', 'products', 'search']));
        for (final r in scoped) {
          expect(
            '${r.headers['X-Store-Id']}',
            '$expectedStoreId',
            reason: r.path,
          );
        }
        final check = calls.where(
          (r) => r.path.startsWith('/api/v1/serviceability/'),
        );
        expect(check, isNotEmpty);
        expect(check.first.headers.containsKey('X-Store-Id'), isFalse);
      }
    },
  );
}
