import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/app/bootstrap.dart';
import 'package:rider_app/app/providers.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/features/auth/data/fake_auth_backend.dart';
import 'package:rider_app/features/auth/presentation/auth_providers.dart';
import 'package:rider_app/features/cash/data/fake_cash_backend.dart';
import 'package:rider_app/features/cash/presentation/cash_providers.dart';
import 'package:rider_app/features/earnings/data/fake_earnings_backend.dart';
import 'package:rider_app/features/earnings/presentation/earnings_providers.dart';
import 'package:rider_app/features/history/data/fake_history_backend.dart';
import 'package:rider_app/features/history/presentation/history_providers.dart';
import 'package:rider_app/features/launch/data/fake_app_config_repository.dart';
import 'package:rider_app/features/launch/presentation/launch_controller.dart';
import 'package:rider_app/features/location/data/location_buffer_file.dart';
import 'package:rider_app/features/location/domain/location_service_client.dart';
import 'package:rider_app/features/location/domain/tracker_stats.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';
import 'package:rider_app/features/location/presentation/location_debug_controller.dart';
import 'package:rider_app/features/offers/data/offer_alert_notifications.dart';
import 'package:rider_app/features/offers/presentation/offer_alert_providers.dart';
import 'package:rider_app/features/onboarding/data/fake_rider_onboarding_backend.dart';
import 'package:rider_app/features/onboarding/domain/image_picking.dart';
import 'package:rider_app/features/onboarding/presentation/onboarding_providers.dart';
import 'package:rider_app/features/notifications/data/api_device_registry.dart';
import 'package:rider_app/features/notifications/data/fake_inbox_backend.dart';
import 'package:rider_app/features/notifications/presentation/inbox_providers.dart';
import 'package:rider_app/features/notifications/presentation/push_providers.dart';
import 'package:rider_app/features/shift/data/fake_shift_backend.dart';
import 'package:rider_app/features/legal/data/legal_repository.dart';
import 'package:rider_app/features/legal/presentation/legal_providers.dart';
import 'package:rider_app/features/rating/data/fake_rating_backend.dart';
import 'package:rider_app/features/rating/presentation/rating_providers.dart';
import 'package:rider_app/features/shift/data/fake_today_summary.dart';
import 'package:rider_app/features/support/data/support_repository.dart';
import 'package:rider_app/features/support/presentation/support_providers.dart';
import 'package:rider_app/features/shift/presentation/home_providers.dart';
import 'package:rider_app/features/shift/presentation/shift_controller.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/presentation/pickup_scan_screen.dart';
import 'package:rider_app/features/task/presentation/task_providers.dart';

import 'kyc_image_fakes.dart';
import 'task_fakes.dart';

/// Location service stand-in: "online" is just a flag.
class FakeLocationServiceClient implements LocationServiceClient {
  bool running = false;
  final _stats = StreamController<TrackerStats>.broadcast();

  @override
  Future<bool> isRunning() async => running;

  @override
  Future<void> start({
    required TrackingConfig config,
    required TrackingMode mode,
    required bool simulateOffline,
    required OnlineNotificationText text,
  }) async {
    calls.add('start(${mode.name})');
    final error = startError;
    if (error != null) {
      startError = null;
      throw error;
    }
    running = true;
    lastConfig = config;
  }

  TrackingConfig? lastConfig;

  /// Runs inside [stop] before it returns (a slow teardown, a log).
  Future<void> Function()? onStop;

  @override
  Future<void> stop() async {
    calls.add('stop');
    await onStop?.call();
    running = false;
  }

  @override
  void setMode(TrackingMode mode) {}

  @override
  void setSimulateOffline(bool value) {}

  @override
  void flush() {}

  @override
  void requestStats() {}

  @override
  Stream<TrackerStats> get stats => _stats.stream;

  final _serverStops = StreamController<String>.broadcast();

  /// A server stop left by the service while the app was closed.
  String? pendingServerStop;
  final calls = <String>[];

  /// Thrown by the next [start].
  Object? startError;

  @override
  void setSimulateServerOffline(bool value) {}

  @override
  Stream<String> get serverStops => _serverStops.stream;

  @override
  Future<String?> takeServerStop() async {
    final code = pendingServerStop;
    pendingServerStop = null;
    return code;
  }

  /// The service stopped itself because the server ended the shift.
  void serverStop(String code) {
    running = false;
    pendingServerStop = code;
    _serverStops.add(code);
  }
}

class RecordingLocationCleaner implements LocationDataCleaner {
  int clears = 0;
  void Function()? onClear;

  @override
  Future<void> clear() async {
    clears++;
    onClear?.call();
  }
}

/// Refresher whose refresh token is always rejected (or [error]).
class FakeTokenRefresher implements TokenRefresher {
  ApiError error = const ApiError(
    code: ApiErrorCode.tokenInvalid,
    statusCode: 401,
  );

  @override
  Future<AuthTokens> refresh(String refreshToken) async => throw error;
}

class NoopOfferAlerts extends OfferAlertNotifications {
  int dismissed = 0;

  @override
  Future<void> dismiss({
    int id = OfferAlertNotifications.testNotificationId,
  }) async => dismissed++;
}

/// Everything a rider-app test needs, with fakes for every platform plugin
/// and the backend.
class RiderTestHarness {
  RiderTestHarness({Flavor flavor = Flavor.dev})
    : env = AppEnv(
        flavor: flavor,
        apiBaseUrl: Uri.parse('http://10.0.2.2:8001'),
        useFakeApi: true,
      );

  final AppEnv env;
  final clientInfo = const ClientInfo(
    appName: 'rider',
    appVersion: '1.0.0',
    buildNumber: '1',
    platform: 'android',
  );
  final tokenStore = InMemoryTokenStore();
  final refresher = FakeTokenRefresher();
  late final session = SessionManager(store: tokenStore, refresher: refresher);
  final signals = AppControlSignals();
  FakeAppConfigRepository config = FakeAppConfigRepository(
    delay: Duration.zero,
  );
  final backend = FakeAuthBackend(delay: Duration.zero);
  final location = FakeLocationServiceClient();
  final urls = FakeUrlOpener();
  final cleaner = RecordingLocationCleaner();
  final offerAlerts = NoopOfferAlerts();

  /// 2026-11-02 12:00 IST.
  DateTime now = DateTime.utc(2026, 11, 2, 6, 30);
  late final onboarding = FakeRiderOnboardingBackend(
    delay: Duration.zero,
    clock: () => now,
  );
  final picker = FakeKycImagePicker();
  final codec = FakeImageCodec();
  final pendingCapture = InMemoryPendingCaptureStore();
  late final tasks = FakeTaskBackend(delay: Duration.zero, clock: () => now);
  final locationReader = FakeLocationReader();
  final earnings = FakeEarningsBackend(delay: Duration.zero);
  late final cash = FakeCashBackend(delay: Duration.zero, clock: () => now);
  late final history = FakeHistoryBackend(
    delay: Duration.zero,
    clock: () => now,
  );
  final alerter = RecordingOfferAlerter();
  final shift = FakeShiftBackend(delay: Duration.zero);
  final today = FakeTodaySummary(delay: Duration.zero);
  final devices = FakeDeviceRegistry();
  late final inbox = FakeInboxBackend(delay: Duration.zero, clock: () => now);
  late final support = FakeSupportBackend(
    delay: Duration.zero,
    clock: () => now,
  );
  late final ratings = FakeRatingBackend(
    delay: Duration.zero,
    clock: () => now,
  );
  final legal = FakeLegalBackend();
  List<String> scannerValues = const ['7K2P', 'HELLO-WORLD'];

  /// The test screen in physical pixels (DPR 2.625): 411×914 dp. Screens
  /// whose lists the tests read whole use a taller one, since the rider
  /// theme's larger text (RD-05) makes them longer than one phone screen.
  Size surface = const Size(1080, 2400);

  List<Override> overrides() => [
    ...riderAppOverrides(
      env: env,
      clientInfo: clientInfo,
      session: session,
      signals: signals,
    ),
    appConfigRepositoryProvider.overrideWithValue(config),
    fakeAuthBackendProvider.overrideWithValue(backend),
    locationServiceClientProvider.overrideWithValue(location),
    urlOpenerProvider.overrideWithValue(urls),
    otpAutofillProvider.overrideWithValue(const NoOtpAutofill()),
    locationDataCleanerProvider.overrideWithValue(cleaner),
    offerAlertNotificationsProvider.overrideWithValue(offerAlerts),
    analyticsProvider.overrideWithValue(const NoopAnalyticsClient()),
    clockProvider.overrideWithValue(() => now),
    fakeRiderOnboardingBackendProvider.overrideWithValue(onboarding),
    kycImagePickerProvider.overrideWithValue(picker),
    imageCodecProvider.overrideWithValue(codec),
    pendingCaptureStoreProvider.overrideWithValue(pendingCapture),
    fakeTaskBackendProvider.overrideWithValue(tasks),
    fakeEarningsBackendProvider.overrideWithValue(earnings),
    fakeCashBackendProvider.overrideWithValue(cash),
    fakeHistoryBackendProvider.overrideWithValue(history),
    currentLocationReaderProvider.overrideWithValue(locationReader),
    offerAlerterProvider.overrideWithValue(alerter),
    fakeShiftBackendProvider.overrideWithValue(shift),
    fakeTodaySummaryProvider.overrideWithValue(today),
    fakeDeviceRegistryProvider.overrideWithValue(devices),
    fakeInboxBackendProvider.overrideWithValue(inbox),
    fakeSupportBackendProvider.overrideWithValue(support),
    fakeRatingBackendProvider.overrideWithValue(ratings),
    fakeLegalBackendProvider.overrideWithValue(legal),
    qrScannerBuilderProvider.overrideWith((ref) => fakeScanner(scannerValues)),
    scannerControllerProvider.overrideWith((ref) => null),
    ...extraOverrides,
  ];

  /// More overrides for every container and pump (e.g. permissions).
  List<Override> extraOverrides = [];

  /// A container for unit tests (session restored first).
  Future<ProviderContainer> container({List<Override> extra = const []}) async {
    await session.restore();
    final container = ProviderContainer(
      retry: noAutomaticRetry,
      overrides: [...overrides(), ...extra],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Stores tokens for [phone] as if the rider had logged in before the app
  /// restarted. Call before [pump].
  Future<void> signedInBefore(String phone) async {
    backend.seedSignedIn(phone);
    await tokenStore.write(
      const AuthTokens(access: 'stored-access', refresh: 'stored-refresh'),
    );
  }

  /// Restores the session (as `bootstrap()` does) and pumps the app on a
  /// phone-sized screen.
  Future<void> pump(
    WidgetTester tester, {
    String? initialLocation,
    bool settle = true,
  }) async {
    await session.restore();
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: [
          ...overrides(),
          if (initialLocation != null)
            initialLocationProvider.overrideWithValue(initialLocation),
        ],
        child: const RiderApp(),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}

/// Pumps frames for [duration] without waiting for timers to settle (the OTP
/// countdown keeps scheduling frames).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 100);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}
