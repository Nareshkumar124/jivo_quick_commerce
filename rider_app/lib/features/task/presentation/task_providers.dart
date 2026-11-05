import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../offers/domain/delivery_offer.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../data/fake_task_backend.dart';
import '../data/platform_task_services.dart';
import '../domain/rider_task.dart';
import '../domain/task_repositories.dart';
import '../domain/task_rules.dart';

/// Whether the rider work screens run: offers and delivery (P5, built ahead
/// in P3) and the rider's records (earnings, payouts, cash, history,
/// profile; built ahead in P4).
///
/// TODO(api): no rider API until the end of P4, so they run only against the
/// fakes, gated like onboarding (DL-30, DL-32): the dev flavor only (also
/// with the real login). Staging and prod keep the Phase 1 home, even with
/// `FAKE_API`.
final riderWorkEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appEnvProvider).flavor == Flavor.dev,
);

/// An ACTIVE rider in a build where the delivery screens run.
final riderWorkActiveProvider = Provider<bool>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return false;
  final account = ref.watch(riderAccountControllerProvider);
  return account is AccountLoaded &&
      account.riderStatus == RiderStatusEnum.ACTIVE;
});

/// TODO(api): the fake offer and task backend. Overridden in tests.
final fakeTaskBackendProvider = Provider<FakeTaskBackend>(
  (ref) => FakeTaskBackend(clock: ref.watch(clockProvider)),
);

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeTaskBackendProvider);
});

final offerEventSourceProvider = Provider<OfferEventSource>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeTaskBackendProvider);
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  return ref.watch(fakeTaskBackendProvider);
});

final navigationLauncherProvider = Provider<NavigationLauncher>(
  (ref) => GeoIntentNavigationLauncher(ref.watch(urlOpenerProvider)),
);

final currentLocationReaderProvider = Provider<CurrentLocationReader>(
  (ref) => const GeolocatorCurrentLocation(),
);

final offerAlerterProvider = Provider<OfferAlerter>(
  (ref) => NotificationOfferAlerter(
    ref.watch(offerAlertNotificationsProvider),
    // The channel is created at startup with its localised name; this is
    // only used if it does not exist yet.
    channelName: lookupAppLocalizations(const Locale('en')).offerChannelName,
  ),
);

/// Staging and prod until the rider API lands: never reached (the
/// controllers do nothing there), every call fails with `NOT_FOUND`.
class _Unavailable
    implements OfferRepository, OfferEventSource, TaskRepository {
  const _Unavailable();

  static const _error = ApiError(code: ApiErrorCode.notFound, statusCode: 404);

  @override
  Stream<OfferEvent> get events => const Stream.empty();

  @override
  Future<ReceivedOffer?> fetchCurrentOffer() async => throw _error;

  @override
  Future<RiderTask> accept(int offerId) async => throw _error;

  @override
  Future<void> reject(int offerId, {OfferRejectReason? reason}) async =>
      throw _error;

  @override
  Future<CurrentTask> fetchCurrentTask() async => throw _error;

  @override
  Future<RiderTask> arrivedAtStore(int taskId, GeoPoint at) async =>
      throw _error;

  @override
  Future<RiderTask> pickup(int taskId, String orderCode) async => throw _error;

  @override
  Future<RiderTask> arrivedAtCustomer(
    int taskId,
    GeoPoint at, {
    String? overrideReason,
  }) async => throw _error;

  @override
  Future<CodQr> createCodQr(int taskId) async => throw _error;

  @override
  Future<RiderTask> deliver(
    int taskId, {
    required String otp,
    CodMode? codMode,
    String? codAmount,
  }) async => throw _error;

  @override
  Future<RiderTask> fail(int taskId, FailReport report) async => throw _error;
}
