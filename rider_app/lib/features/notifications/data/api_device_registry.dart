import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show AppEnum, DeviceRequest, JivoApi, PlatformEnum;
import 'package:jivo_core/jivo_core.dart';

import '../domain/device_registry.dart';

/// `POST /api/v1/me/devices/` through the generated client.
class ApiDeviceRegistry implements DeviceRegistry {
  ApiDeviceRegistry(this._api, this._clientInfo);

  final JivoApi _api;
  final ClientInfo _clientInfo;

  /// `1.0.0+1`: the schema's `app_version` pattern allows the build number.
  String get _appVersion => _clientInfo.buildNumber.isEmpty
      ? _clientInfo.appVersion
      : '${_clientInfo.appVersion}+${_clientInfo.buildNumber}';

  @override
  Future<void> register(String fcmToken) async {
    try {
      await _api.getAccountApi().meDeviceRegister(
        deviceRequest: DeviceRequest(
          fcmToken: fcmToken,
          app: AppEnum.rider,
          // Android only in v1 (D-07).
          platform: PlatformEnum.android,
          appVersion: _appVersion,
        ),
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  /// TODO(api): the schema's DELETE has no `requestBody`, so the generated
  /// `meDeviceUnregister()` cannot send the `fcm_token` the server requires
  /// (its 400 example). Sent through the same Dio with that body until the
  /// schema declares it.
  @override
  Future<void> unregister(String fcmToken) async {
    try {
      await _api.dio.delete<void>(
        '/api/v1/me/devices/',
        data: {'fcm_token': fcmToken},
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// `FAKE_API` builds and tests: remembers the tokens it was given.
class FakeDeviceRegistry implements DeviceRegistry {
  final registered = <String>[];
  final unregistered = <String>[];

  /// Thrown (once) by the next [register].
  ApiError? nextError;

  @override
  Future<void> register(String fcmToken) async {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    registered.add(fcmToken);
  }

  @override
  Future<void> unregister(String fcmToken) async {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    unregistered.add(fcmToken);
  }
}
