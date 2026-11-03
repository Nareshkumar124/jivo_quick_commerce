import 'dart:convert';

import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/auth/data/fake_token_refresher.dart';
import 'package:customer_app/features/cart/data/api_cart_repository.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/catalog/data/api_catalog_repository.dart';
import 'package:customer_app/features/catalog/data/fake_catalog_repository.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/catalog/presentation/catalog_controllers.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/checkout/data/gateway_payment_launcher.dart';
import 'package:customer_app/features/checkout/data/razorpay_payment_launcher.dart';
import 'package:customer_app/features/location/data/api_serviceability_repository.dart';
import 'package:customer_app/features/location/data/delivery_location_store.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/location/presentation/delivery_controller.dart';
import 'package:customer_app/features/orders/data/api_order_repository.dart';
import 'package:customer_app/features/orders/data/order_repository.dart';
import 'package:customer_app/features/search/presentation/search_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_config.dart';

Future<ProviderContainer> containerFor(
  AppEnv env, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(
    overrides: [
      appEnvProvider.overrideWithValue(env),
      clientInfoProvider.overrideWithValue(testClientInfo),
      sessionProvider.overrideWithValue(
        SessionManager(
          store: InMemoryTokenStore(),
          refresher: FakeTokenRefresher(),
        ),
      ),
      appControlProvider.overrideWithValue(AppControlSignals()),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final staging = AppEnv.resolve(
  flavor: Flavor.staging,
  apiBaseUrl: 'https://staging.example.in',
  useFakeApi: true,
);
final prod = AppEnv.resolve(
  flavor: Flavor.prod,
  apiBaseUrl: 'https://api.example.in',
  useFakeApi: true,
);

const storeJson = {
  'id': 7,
  'name': 'Jivo Sector 14, Gurugram',
  'is_open': true,
  'opens_at': null,
};

Map<String, Object?> variantJson({int id = 101}) => {
  'id': id,
  'name': '1 L',
  'mrp': '299.00',
  'selling_price': '249.00',
  'discount_amount': '50.00',
  'discount_percent': 16,
  'unit_price': {'amount': '24.90', 'per': '100 ml'},
  'stock_status': 'LOW_STOCK',
  'orderable_quantity': 2,
  'units_left': 2,
  'max_qty_per_order': 5,
  'image': null,
};

Map<String, Object?> cardJson() => {
  'id': 1,
  'slug': 'jivo-canola-oil',
  'name': 'Jivo Canola Oil',
  'brand': 'Jivo',
  'is_veg': true,
  'image': null,
  'default_variant_id': 101,
  'variants': [variantJson()],
};

const tileJson = {
  'id': 1,
  'name': 'Edible Oils',
  'slug': 'edible-oils',
  'image': null,
};

Map<String, Object?> detailJson() => {
  'id': 1,
  'slug': 'jivo-canola-oil',
  'name': 'Jivo Canola Oil',
  'brand': 'Jivo',
  'is_veg': true,
  'category': tileJson,
  'short_description': 'Light taste for daily cooking.',
  'description': 'Jivo Canola Oil.',
  'highlights': ['Light taste'],
  'default_variant_id': 101,
  'variants': [
    {
      ...variantJson(),
      'sku': 'JV-CAN-RF-1L',
      'net_quantity': '1 L',
      'images': <Object>[],
    },
  ],
  'ingredients': 'Refined canola oil.',
  'nutrition': null,
  'shelf_life': '9 months',
  'storage_instructions': 'Store in a cool, dry place.',
  'country_of_origin': 'India',
  'manufacturer': 'Jivo Wellness',
  'marketer': '',
  'importer': '',
  'consumer_care': 'care@example.in',
  'fssai_license_no': '10020064000123',
  'similar_products': <Object>[],
};

/// Answers like the backend: serviceability and every catalog endpoint.
(int, Object?) backend(RequestOptions request) {
  final path = request.path;
  if (path.startsWith('/api/v1/categories/')) {
    return (
      200,
      {
        'results': [
          {...tileJson, 'children': <Object>[]},
        ],
      },
    );
  }
  if (path.startsWith('/api/v1/collections/')) {
    return (
      200,
      {
        'id': 1,
        'name': 'Bestsellers',
        'slug': 'bestsellers',
        'products': [cardJson()],
      },
    );
  }
  if (path.startsWith('/api/v1/search/suggest/')) {
    return (
      200,
      {
        'query': '${request.queryParameters['q'] ?? ''}',
        'suggestions': [
          {
            'id': 1,
            'type': 'product',
            'text': 'Jivo Canola Oil',
            'query': 'Jivo Canola Oil',
            'slug': 'jivo-canola-oil',
            'image': null,
          },
        ],
      },
    );
  }
  if (path.startsWith('/api/v1/search/')) {
    return (
      200,
      {
        'count': 1,
        'next': null,
        'previous': null,
        'results': [cardJson()],
      },
    );
  }
  if (path == '/api/v1/products/jivo-canola-oil/') {
    return (200, detailJson());
  }
  if (path.startsWith('/api/v1/serviceability/')) {
    return (
      200,
      {
        'serviceable': true,
        'store': storeJson,
        'eta_minutes': 22,
        'message': null,
      },
    );
  }
  if (path.startsWith('/api/v1/home/')) {
    return (
      200,
      {
        'store': storeJson,
        'banners': [
          {
            'id': 1,
            'title': 'Offers',
            'image': {
              'thumbnail': 'https://cdn.example.in/b-t.jpg',
              'medium': 'https://cdn.example.in/b-m.jpg',
              'large': 'https://cdn.example.in/b-l.jpg',
              'alt_text': '',
            },
            'link_type': 'collection',
            'link_value': 'offers',
          },
        ],
        'categories': [
          {
            'id': 1,
            'name': 'Edible Oils',
            'slug': 'edible-oils',
            'image': null,
          },
        ],
        'collections': [
          {
            'id': 1,
            'name': 'Bestsellers',
            'slug': 'bestsellers',
            'products': [cardJson()],
            'has_more': true,
          },
        ],
        'buy_again': <Object>[],
      },
    );
  }
  if (path.startsWith('/api/v1/products/')) {
    return (
      200,
      {
        'count': 21,
        'next': 'http://x/api/v1/products/?page=2',
        'previous': null,
        'results': [cardJson()],
      },
    );
  }
  return (
    404,
    {
      'error': {'code': 'NOT_FOUND', 'message': 'x', 'details': {}},
    },
  );
}

void main() {
  group('flavors', () {
    test('staging and prod never use the fakes, even with FAKE_API', () async {
      for (final env in [staging, prod]) {
        final container = await containerFor(env);
        expect(
          container.read(catalogRepositoryProvider),
          isA<ApiCatalogRepository>(),
          reason: env.flavor.name,
        );
        expect(
          container.read(serviceabilityRepositoryProvider),
          isA<ApiServiceabilityRepository>(),
          reason: env.flavor.name,
        );
        expect(container.read(cartAvailableProvider), isFalse);
        expect(
          container.read(cartRepositoryProvider),
          isA<UnavailableCartRepository>(),
        );
        expect(
          container.read(orderRepositoryProvider),
          isA<UnavailableOrderRepository>(),
        );
        // Real Razorpay only: no fake behind it.
        final launcher = container.read(paymentLauncherProvider);
        expect(launcher, isA<GatewayPaymentLauncher>());
        launcher as GatewayPaymentLauncher;
        expect(launcher.real, isA<RazorpayPaymentLauncher>());
        expect(launcher.fake, isNull);
      }
    });

    test('dev uses the real API; FAKE_API swaps in the fakes', () async {
      final dev = await containerFor(testEnv);
      expect(dev.read(catalogRepositoryProvider), isA<ApiCatalogRepository>());
      expect(
        dev.read(serviceabilityRepositoryProvider),
        isA<ApiServiceabilityRepository>(),
      );
      // The cart is dev-only until S3-B; dev talks to the real API.
      expect(dev.read(cartAvailableProvider), isTrue);
      expect(dev.read(cartRepositoryProvider), isA<ApiCartRepository>());
      expect(dev.read(orderRepositoryProvider), isA<ApiOrderRepository>());
      final launcher =
          dev.read(paymentLauncherProvider) as GatewayPaymentLauncher;
      expect(launcher.real, isA<RazorpayPaymentLauncher>());
      expect(launcher.fake, isA<FakePaymentLauncher>()); // rzp_fake_ keys

      final fake = await containerFor(
        AppEnv.resolve(flavor: Flavor.dev, useFakeApi: true),
      );
      expect(
        fake.read(catalogRepositoryProvider),
        isA<FakeCatalogRepository>(),
      );
      expect(
        fake.read(serviceabilityRepositoryProvider),
        isA<FakeServiceabilityRepository>(),
      );
      expect(fake.read(cartRepositoryProvider), isA<FakeCommerceBackend>());
      expect(
        identical(
          fake.read(cartRepositoryProvider),
          fake.read(orderRepositoryProvider),
        ),
        isTrue,
      );
    });
  });

  test('X-Store-Id goes out on catalog calls, not on serviceability', () async {
    final container = await containerFor(
      testEnv,
      prefs: {
        DeliveryLocationStore.key: jsonEncode(testDeliveryLocation.toJson()),
      },
    );
    final http = FakeHttp(backend);
    container.read(dioProvider).httpClientAdapter = http;

    // Restoring the saved location checks serviceability: store 7.
    container.read(deliveryProvider);
    await pumpEventQueue();
    expect(container.read(currentStoreIdProvider), 7);

    final feed = await container.read(catalogRepositoryProvider).home();
    await container
        .read(catalogRepositoryProvider)
        .products(category: 'edible-oils');

    final check = http.requests.firstWhere(
      (r) => r.path.contains('/serviceability/'),
    );
    expect(check.headers.containsKey('X-Store-Id'), isFalse);
    for (final path in ['/api/v1/home/', '/api/v1/products/']) {
      final request = http.requests.firstWhere((r) => r.path == path);
      expect('${request.headers['X-Store-Id']}', '7', reason: path);
      expect(request.headers['X-App-Name'], 'customer', reason: path);
    }
    expect(feed.store?.name, 'Jivo Sector 14, Gurugram');
  });

  test(
    'every catalog provider sends X-Store-Id through the shared Dio',
    () async {
      final container = await containerFor(
        testEnv,
        prefs: {
          DeliveryLocationStore.key: jsonEncode(testDeliveryLocation.toJson()),
        },
      );
      final http = FakeHttp(backend);
      container.read(dioProvider).httpClientAdapter = http;
      container.read(deliveryProvider);
      await pumpEventQueue();
      expect(container.read(currentStoreIdProvider), 7);

      /// Keeps an auto-dispose provider alive while its future loads.
      Future<T> load<T>(ProviderListenable<Future<T>> provider) {
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        return subscription.read();
      }

      await load(homeFeedProvider.future);
      await load(categoriesProvider.future);
      await load(productDetailProvider('jivo-canola-oil').future);
      await load(trendingSearchesProvider.future);
      const category = CategoryQuery('edible-oils');
      final first = await load(pagedProductsProvider(category).future);
      expect(first.hasMore, isTrue);
      // The paged list's next page goes through the same path.
      await container.read(pagedProductsProvider(category).notifier).loadMore();
      await load(
        pagedProductsProvider(const CollectionQuery('bestsellers')).future,
      );
      await load(pagedProductsProvider(const SearchQuery('canola')).future);
      // Typeahead from the search screen, after the debounce.
      final search = container.listen(searchControllerProvider, (_, _) {});
      addTearDown(search.close);
      container.read(searchControllerProvider.notifier).onChanged('can');
      await Future<void>.delayed(
        kSearchDebounce + const Duration(milliseconds: 50),
      );
      await pumpEventQueue();

      final catalogCalls = http.requests
          .where((r) => !r.path.startsWith('/api/v1/serviceability/'))
          .toList();
      expect(
        {for (final r in catalogCalls) r.path},
        {
          '/api/v1/home/',
          '/api/v1/categories/',
          '/api/v1/products/jivo-canola-oil/',
          '/api/v1/search/suggest/',
          '/api/v1/products/',
          '/api/v1/collections/bestsellers/',
          '/api/v1/search/',
        },
      );
      for (final r in catalogCalls) {
        expect('${r.headers['X-Store-Id']}', '7', reason: r.uri.toString());
      }
      final productPages = [
        for (final r in catalogCalls)
          if (r.path == '/api/v1/products/') r.queryParameters['page'],
      ];
      expect(productPages, [1, 2]);
      final suggestQueries = [
        for (final r in catalogCalls)
          if (r.path == '/api/v1/search/suggest/') r.queryParameters['q'],
      ];
      expect(suggestQueries, ['', 'can']);
    },
  );

  test('the API repository maps the contract into the app models', () async {
    final http = FakeHttp(backend);
    final repository = ApiCatalogRepository(http.api(), () => 7);

    final feed = await repository.home();
    final card = feed.collections.single.items.single;
    final variant = card.defaultVariant;
    expect(feed.collections.single.hasMore, isTrue);
    expect(feed.banners.single.link, isA<CollectionBannerLink>());
    expect(feed.banners.single.imageUrl, 'https://cdn.example.in/b-l.jpg');
    expect(variant.sellingPrice, '249.00');
    expect(variant.stockStatus, StockStatus.lowStock);
    expect(variant.lowStockUnits, 2);
    expect(variant.maxSelectable, 2);
    expect(variant.unitPrice, (amount: '24.90', per: '100 ml'));

    final page = await repository.products(category: 'edible-oils');
    expect(page.nextPage, 2);
    expect(http.requests.last.queryParameters['page_size'], 20);
  });

  test('without a store the catalog asks for the location again', () async {
    final http = FakeHttp(backend);
    final repository = ApiCatalogRepository(http.api(), () => null);
    await expectLater(
      repository.home(),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.storeNotFound,
        ),
      ),
    );
    expect(http.requests, isEmpty);
  });

  test('serviceability maps a 200 "not serviceable" with no store', () async {
    final http = FakeHttp(
      (_) => (
        200,
        {
          'serviceable': false,
          'store': null,
          'eta_minutes': null,
          'message': "We're not in your area yet",
        },
      ),
    );
    final result = await ApiServiceabilityRepository(http.api())
        .check((lat: 19.07, lng: 72.87));
    expect(result.serviceable, isFalse);
    expect(result.store, isNull);
    expect(http.requests.single.queryParameters['lat'], 19.07);
  });
}
