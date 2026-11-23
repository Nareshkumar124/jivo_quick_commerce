import 'package:customer_app/app/launch_state.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/launch/domain/launch_config.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:customer_app/features/tracking/presentation/tracking_screen.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/fake_ws.dart';
import '../../helpers/widget_harness.dart';

/// Tracking layout spec (CA-25/26): OTP above the map, freshness line,
/// late notice, text scale.
void main() {
  final now = DateTime.utc(2026, 11, 14, 10);

  Widget routed(
    Widget child, {
    required bool support,
    String? phone,
    FakeUrlOpener? urls,
    required List<String> pushed,
  }) {
    final launch = LaunchState(onboardingSeen: true);
    if (phone != null) {
      launch.configLoaded(
        LaunchConfig(
          maintenance: false,
          termsVersion: '1',
          policies: PolicyLinks(
            terms: Uri.parse('https://x/t'),
            privacy: Uri.parse('https://x/p'),
            refund: Uri.parse('https://x/r'),
          ),
          supportPhone: phone,
        ),
        updateAvailable: false,
      );
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
        ),
        GoRoute(
          path: '/account/help/new',
          builder: (_, state) {
            pushed.add(state.uri.toString());
            return const Scaffold(body: Text('new ticket'));
          },
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        launchStateProvider.overrideWithValue(launch),
        supportAvailableProvider.overrideWithValue(support),
        if (urls != null) urlOpenerProvider.overrideWithValue(urls),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: JivoTheme.light(),
        locale: const Locale('en', 'IN'),
        supportedLocales: const [Locale('en', 'IN')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          JivoCoreLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  List<Override> screenOverrides(FakeTrackRepository repo) => [
    trackRepositoryProvider.overrideWithValue(repo),
    trackPollIntervalProvider.overrideWithValue(Duration.zero),
    supportAvailableProvider.overrideWithValue(true),
  ];

  testWidgets('the OTP card is above the route sketch while out for delivery', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const TrackingScreen(orderId: 3),
        overrides: screenOverrides(FakeTrackRepository(startStep: 2)),
      ),
    );
    await tester.pumpAndSettle();
    final otp = tester.getTopLeft(find.byKey(const Key('delivery-otp'))).dy;
    final map = tester.getTopLeft(find.byKey(const Key('route-sketch'))).dy;
    expect(otp, lessThan(map));
  });

  group('freshness line', () {
    testWidgets('Live, then Updated after the socket is down over 5 s', (
      tester,
    ) async {
      final rt = FakeOrderRealtime();
      await tester.pumpWidget(
        harness(
          const TrackingScreen(orderId: 3),
          realtime: rt,
          overrides: screenOverrides(FakeTrackRepository(startStep: 2)),
        ),
      );
      await tester.pumpAndSettle();
      rt.server.last.authOk();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('tracking-fresh-live')), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);

      rt.server.last.serverClose(1006);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('tracking-fresh-live')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const Key('tracking-fresh-live')), findsNothing);
      expect(find.byKey(const Key('tracking-fresh-polling')), findsOneWidget);
      expect(find.textContaining('Updated '), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets(
      'a failed poll shows the stale line; pull to refresh clears it',
      (tester) async {
        final repo = FakeTrackRepository(startStep: 2);
        await tester.pumpWidget(
          harness(
            const TrackingScreen(orderId: 3),
            overrides: screenOverrides(repo),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tracking-fresh-polling')), findsOneWidget);

        repo.failNext = const ApiError(code: ApiErrorCode.network);
        await tester.fling(
          find.byKey(const Key('tracking')),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tracking-fresh-stale')), findsOneWidget);
        expect(find.textContaining('update right now'), findsOneWidget);

        await tester.fling(
          find.byKey(const Key('tracking')),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tracking-fresh-stale')), findsNothing);
        expect(find.byKey(const Key('tracking-fresh-polling')), findsOneWidget);
      },
    );
  });

  group('late notice', () {
    Future<void> pumpEta(
      WidgetTester tester, {
      required Duration pastEta,
      required OrderStatus status,
      bool support = true,
      String? phone,
      FakeUrlOpener? urls,
      List<String>? pushed,
    }) async {
      await tester.pumpWidget(
        routed(
          EtaCountdown(
            etaAt: now.subtract(pastEta),
            status: status,
            orderId: 7,
            now: () => now,
          ),
          support: support,
          phone: phone,
          urls: urls,
          pushed: pushed ?? [],
        ),
      );
      await tester.pump();
    }

    testWidgets('not late up to 5 minutes past the ETA', (tester) async {
      await pumpEta(
        tester,
        pastEta: const Duration(minutes: 5),
        status: OrderStatus.outForDelivery,
      );
      expect(find.byKey(const Key('tracking-late')), findsNothing);
      expect(find.text('Arriving any moment'), findsOneWidget);
    });

    testWidgets('late while out for delivery; Get help opens support', (
      tester,
    ) async {
      final pushed = <String>[];
      await pumpEta(
        tester,
        pastEta: const Duration(minutes: 5, seconds: 1),
        status: OrderStatus.outForDelivery,
        pushed: pushed,
      );
      expect(
        find.text('Running a little late. Your rider is on the way.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('tracking-get-help')));
      await tester.pumpAndSettle();
      expect(pushed.single, Routes.newTicket(orderId: 7));
    });

    testWidgets('late before pickup; support off calls the support phone', (
      tester,
    ) async {
      final urls = FakeUrlOpener();
      await pumpEta(
        tester,
        pastEta: const Duration(minutes: 9),
        status: OrderStatus.packing,
        support: false,
        phone: '+911800000000',
        urls: urls,
      );
      expect(
        find.text(
          'Taking a little longer than planned. Your order is being prepared.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Call support'));
      expect(urls.opened.single, Uri.parse('tel:+911800000000'));
    });

    testWidgets('no support and no phone: no button', (tester) async {
      await pumpEta(
        tester,
        pastEta: const Duration(minutes: 9),
        status: OrderStatus.outForDelivery,
        support: false,
      );
      expect(find.byKey(const Key('tracking-late')), findsOneWidget);
      expect(find.byKey(const Key('tracking-get-help')), findsNothing);
    });
  });

  testWidgets('2.0x text on 360 dp: no overflow, OTP on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        const TrackingScreen(orderId: 3),
        textScaler: const TextScaler.linear(2),
        overrides: screenOverrides(FakeTrackRepository(startStep: 2)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final code = tester.getSize(find.byKey(const Key('delivery-otp-code')));
    expect(code.width, lessThanOrEqualTo(360));
    expect(find.byKey(const Key('delivery-otp')), findsOneWidget);
  });
}
