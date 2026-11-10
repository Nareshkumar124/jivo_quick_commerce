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
import '../../realtime/presentation/rider_socket_providers.dart';
import '../data/api_task_repository.dart';
import '../data/fake_task_backend.dart';
import '../data/platform_task_services.dart';
import '../domain/rider_task.dart';
import '../domain/task_repositories.dart';
import '../domain/task_rules.dart';

/// Whether the rider work screens run: offers and delivery (P5, built ahead
/// in P3) and the rider's records (earnings, payouts, cash, history,
/// profile; built ahead in P4).
///
/// Bound to the generated client (P5 slices 5.3/5.4; the fakes with
/// `FAKE_API`), still gated like onboarding (DL-30, DL-32): the dev flavor
/// only, until the PM opens them for staging. Staging and prod keep the
/// Phase 1 home, even with `FAKE_API`.
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

/// The fake offer and task backend (`FAKE_API` builds). Overridden in
/// tests.
final fakeTaskBackendProvider = Provider<FakeTaskBackend>(
  (ref) => FakeTaskBackend(clock: ref.watch(clockProvider)),
);

/// The offer and task endpoints through the generated client (T-515b).
final apiTaskRepositoryProvider = Provider<ApiTaskRepository>(
  (ref) => ApiTaskRepository(ref.watch(jivoApiProvider)),
);

/// Offers, offer events and the task: the generated client, or the fake
/// with `FAKE_API`. Only where the rider work screens run (dev flavor,
/// DL-30/DL-32).
T _taskBackend<T extends Object>(Ref ref, T unavailable) {
  if (!ref.watch(riderWorkEnabledProvider)) return unavailable;
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeTaskBackendProvider) as T;
  }
  return ref.watch(apiTaskRepositoryProvider) as T;
}

final offerRepositoryProvider = Provider<OfferRepository>(
  (ref) => _taskBackend<OfferRepository>(ref, const _Unavailable()),
);

/// Pushed offer events: the fake's in `FAKE_API` builds, otherwise the
/// rider socket's (`/ws/v1/rider/`, P6).
final offerEventSourceProvider = Provider<OfferEventSource>((ref) {
  if (!ref.watch(riderWorkEnabledProvider)) return const _Unavailable();
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeTaskBackendProvider);
  }
  return ref.watch(socketOfferEventsProvider);
});

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => _taskBackend<TaskRepository>(ref, const _Unavailable()),
);

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

/// Staging and prod while gated: never reached (the
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
