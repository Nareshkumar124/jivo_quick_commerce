import 'dart:typed_data';

import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/shared/connectivity/connectivity.dart';
import 'package:customer_app/shared/network/network_health_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../helpers/test_app.dart';

/// CA-03: a failed refresh keeps what is on screen. CA-02: "no internet"
/// after 2 network failures, and error screens retry on reconnect.

const network = ApiError(code: ApiErrorCode.network);
final refreshFailed = find.text("Couldn't refresh. Check your connection.");

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 7000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Runs the screen's own pull-to-refresh (the last RefreshIndicator).
Future<void> pullToRefresh(WidgetTester tester) async {
  final indicator = tester.state<RefreshIndicatorState>(
    find.byType(RefreshIndicator).last,
  );
  final done = indicator.show();
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

/// Answers every request with [respond].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(initializeFormatting);

  group('CA-03: a failed refresh keeps the content', () {
    testWidgets('home', (tester) async {
      tallView(tester);
      final app = TestApp(tokens: signedInTokens);
      await app.pump(tester);
      expect(find.text('Shop by category'), findsOneWidget);

      app.catalog.failNext = network;
      await pullToRefresh(tester);
      expect(app.catalog.failNext, isNull, reason: 'the refresh ran');

      expect(find.text('Shop by category'), findsOneWidget);
      expect(find.text('Bestsellers'), findsOneWidget);
      expect(refreshFailed, findsOneWidget);
      expect(find.text('Retry'), findsOneWidget, reason: 'snackbar action');
    });

    testWidgets('a product grid', (tester) async {
      tallView(tester);
      final app = TestApp(tokens: signedInTokens);
      await app.pump(tester);
      GoRouter.of(tester.element(find.byType(HomeScreen)))
          .push(Routes.category('edible-oils'));
      await tester.pumpAndSettle();
      final tiles = find.byType(Card);
      final before = tester.widgetList(tiles).length;
      expect(before, greaterThan(0));

      app.catalog.failNext = network;
      await pullToRefresh(tester);
      expect(app.catalog.failNext, isNull, reason: 'the refresh ran');

      expect(tester.widgetList(tiles).length, before);
      expect(refreshFailed, findsOneWidget);
    });
  });

  group('CA-02: reconnect', () {
    testWidgets('an error screen retries by itself when the connection is '
        'back, and the banner goes away', (tester) async {
      tallView(tester);
      final app = TestApp(tokens: signedInTokens);
      app.catalog.failNext = network;
      await app.pump(tester);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Shop by category'), findsNothing);

      app.connectivity.add(false);
      await tester.pumpAndSettle();
      expect(find.text('No internet connection'), findsOneWidget);
      expect(
        find.text("We'll update as soon as you're back online."),
        findsOneWidget,
      );

      app.connectivity.add(true);
      await tester.pumpAndSettle();
      expect(find.text('No internet connection'), findsNothing);
      expect(find.text('Shop by category'), findsOneWidget);
    });

    test('two network failures in a row mean "no internet"; any answer '
        'clears it and counts as a reconnect', () async {
      final container = ProviderContainer(
        overrides: [
          connectivityStreamProvider.overrideWithValue(const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final reconnects = <int>[];
      container.listen(reconnectProvider, (_, next) => reconnects.add(next));
      var answers = true;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.in'))
        ..httpClientAdapter = _Adapter((options) {
          if (!answers) {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'no route',
            );
          }
          return ResponseBody.fromString('{}', 500);
        })
        ..interceptors.add(
          NetworkHealthInterceptor(
            onFailed: () =>
                container.read(networkHealthProvider.notifier).failed(),
            onAnswered: () =>
                container.read(networkHealthProvider.notifier).answered(),
          ),
        );
      Future<void> call() async {
        try {
          await dio.get<Object?>('/x');
        } on DioException {
          // Counted by the interceptor.
        }
      }

      answers = false;
      await call();
      expect(container.read(connectionLostProvider), isFalse);
      await call();
      expect(container.read(connectionLostProvider), isTrue);

      answers = true; // even a 500 is an answer: the server is reachable
      await call();
      expect(container.read(connectionLostProvider), isFalse);
      expect(reconnects, [1]);
    });
  });
}
