import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show AppEnum, DeviceRequest, JivoApi, PlatformEnum;
import 'package:jivo_core/jivo_core.dart';

/// This device's push registration (`POST /me/devices/`, `06 §2.2`).
abstract interface class DeviceRepository {
  /// Upserts the device keyed on [fcmToken]: after login, on every token
  /// refresh and when the app version changes. Throws [ApiError].
  Future<void> register({
    required String fcmToken,
    required String platform,
    required String appVersion,
  });
}

class ApiDeviceRepository implements DeviceRepository {
  const ApiDeviceRepository(this._api);

  final JivoApi _api;

  @override
  Future<void> register({
    required String fcmToken,
    required String platform,
    required String appVersion,
  }) async {
    try {
      await _api.getAccountApi().meDeviceRegister(
        deviceRequest: DeviceRequest(
          fcmToken: fcmToken,
          app: AppEnum.customer,
          platform: platform == 'ios' ? PlatformEnum.ios : PlatformEnum.android,
          appVersion: appVersion,
        ),
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// One registration call, as the fake saw it.
typedef DeviceRegistration = ({
  String fcmToken,
  String platform,
  String appVersion,
});

/// Records registrations (`FAKE_API=true` and tests).
class FakeDeviceRepository implements DeviceRepository {
  final List<DeviceRegistration> calls = [];

  /// When set, the next call throws it once.
  Object? failNext;

  @override
  Future<void> register({
    required String fcmToken,
    required String platform,
    required String appVersion,
  }) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    calls.add((
      fcmToken: fcmToken,
      platform: platform,
      appVersion: appVersion,
    ));
  }
}
