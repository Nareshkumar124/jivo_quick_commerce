/// Registers this device's push token for the signed-in rider
/// (`POST /api/v1/me/devices/`, P1 contract: an upsert keyed on the token).
abstract interface class DeviceRegistry {
  /// Throws a jivo_core `ApiError` on failure.
  Future<void> register(String fcmToken);

  /// `DELETE /api/v1/me/devices/` (`me_device_unregister`): stops push to
  /// this token, e.g. on logout. Throws a jivo_core `ApiError` on failure.
  Future<void> unregister(String fcmToken);
}
