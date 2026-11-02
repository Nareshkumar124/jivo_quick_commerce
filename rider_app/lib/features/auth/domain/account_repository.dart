import 'package:jivo_api/jivo_api.dart' show Me;

/// The signed-in user (`GET /api/v1/me/`), including `rider_status`.
abstract interface class AccountRepository {
  /// Throws jivo_core's `ApiError` on failure.
  Future<Me> fetchMe();
}
