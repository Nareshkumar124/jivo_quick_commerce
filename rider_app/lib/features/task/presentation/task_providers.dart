import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../../realtime/presentation/rider_socket_providers.dart';
import '../data/api_task_repository.dart';
import '../data/fake_task_backend.dart';
import '../data/platform_task_services.dart';
import '../domain/task_repositories.dart';

/// An ACTIVE rider: the offer, task and shift controllers run only then.
final riderWorkActiveProvider = Provider<bool>((ref) {
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
/// with `FAKE_API` (DL-30/DL-32).
T _taskBackend<T extends Object>(Ref ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeTaskBackendProvider) as T;
  }
  return ref.watch(apiTaskRepositoryProvider) as T;
}

final offerRepositoryProvider = Provider<OfferRepository>(
  (ref) => _taskBackend<OfferRepository>(ref),
);

/// Pushed offer events: the fake's in `FAKE_API` builds, otherwise the
/// rider socket's (`/ws/v1/rider/`, P6).
final offerEventSourceProvider = Provider<OfferEventSource>((ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeTaskBackendProvider);
  }
  return ref.watch(socketOfferEventsProvider);
});

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => _taskBackend<TaskRepository>(ref),
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
