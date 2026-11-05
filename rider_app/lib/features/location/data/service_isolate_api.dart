import 'package:flutter/foundation.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi;
import 'package:jivo_core/jivo_core.dart';

import '../../../shared/session/store_synced_token_refresher.dart';
import '../domain/location_uploader.dart';
import 'api_location_uploader.dart';
import 'fake_location_uploader.dart';

/// Which backend the location service talks to. The service runs in its own
/// isolate (its own Flutter engine), where the UI's providers and
/// compile-time flavor are not available, so the UI saves this with the
/// service settings.
@immutable
class ServiceApiSettings {
  const ServiceApiSettings({
    required this.flavor,
    required this.apiBaseUrl,
    required this.useFakeApi,
  });

  factory ServiceApiSettings.fromEnv(AppEnv env, {required bool live}) =>
      ServiceApiSettings(
        flavor: env.flavor.name,
        apiBaseUrl: env.apiBaseUrl.toString(),
        // The fake also covers builds where the rider API is not bound.
        useFakeApi: env.useFakeApi || !live,
      );

  factory ServiceApiSettings.fromJson(Map<String, dynamic> json) =>
      ServiceApiSettings(
        flavor: json['flavor'] as String,
        apiBaseUrl: json['api_base_url'] as String,
        useFakeApi: json['use_fake_api'] as bool,
      );

  /// Before the shift API existed: fake uploads.
  static const fake = ServiceApiSettings(
    flavor: 'dev',
    apiBaseUrl: 'http://localhost',
    useFakeApi: true,
  );

  final String flavor;
  final String apiBaseUrl;
  final bool useFakeApi;

  Map<String, dynamic> toJson() => {
    'flavor': flavor,
    'api_base_url': apiBaseUrl,
    'use_fake_api': useFakeApi,
  };

  @override
  bool operator ==(Object other) =>
      other is ServiceApiSettings &&
      other.flavor == flavor &&
      other.apiBaseUrl == apiBaseUrl &&
      other.useFakeApi == useFakeApi;

  @override
  int get hashCode => Object.hash(flavor, apiBaseUrl, useFakeApi);
}

/// Builds the uploader for the service isolate.
///
/// The real one gets its own [SessionManager] over the same secure token
/// store as the UI, with [StoreSyncedTokenRefresher], so a refresh by either
/// isolate never ends the other's session (refresh tokens rotate and work
/// once). If the session really is over, uploads answer 401 and the tracker
/// stops ([UploadTrackingStopped]).
Future<LocationUploader> createServiceUploader(
  ServiceApiSettings settings, {
  bool simulateOffline = false,
  bool simulateServerOffline = false,
}) async {
  if (settings.useFakeApi) {
    return FakeLocationUploader(
      simulateOffline: simulateOffline,
      simulateServerOffline: simulateServerOffline,
    );
  }
  final env = AppEnv(
    flavor: Flavor.values.byName(settings.flavor),
    apiBaseUrl: Uri.parse(settings.apiBaseUrl),
    useFakeApi: false,
  );
  final clientInfo = await ClientInfo.fromPlatform(appName: 'rider');
  final secureStore = SecureTokenStore();
  final session = SessionManager(
    store: GuardedTokenStore(secureStore),
    refresher: StoreSyncedTokenRefresher(
      inner: ApiTokenRefresher.forEnv(env: env, clientInfo: clientInfo),
      store: secureStore,
    ),
  );
  await session.restore();
  final dio = createJivoDio(
    env: env,
    clientInfo: clientInfo,
    interceptors: [AuthInterceptor(session)],
  );
  return ApiLocationUploader(JivoApi(dio: dio, interceptors: const []));
}
