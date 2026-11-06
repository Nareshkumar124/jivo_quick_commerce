import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi, RiderProfile;
import 'package:jivo_core/jivo_core.dart';

/// `GET /rider/me/` with the fields the generated model does not have yet.
class RiderMe {
  const RiderMe(this.profile, {required this.depositRequired});

  final RiderProfile profile;

  /// `cash.deposit_required` (DL-61 b): show "Deposit cash" because the
  /// rider is at the limit, or a COD order was skipped because cash in hand
  /// plus its amount was over the limit. Falls back to `limit_reached`
  /// while the server does not send it.
  final bool depositRequired;
}

/// Reads `GET /rider/me/` once, parsed by the generated model.
///
/// TODO(api): `cash.deposit_required` is in the backend's slice 5.4
/// serializer but not yet in the exported schema, so the generated
/// `RiderCash` drops it. Read it from the raw body until the PM regenerates
/// `jivo_api`; then use `profile.cash.depositRequired` and the generated
/// `riderMeRetrieve()` again.
Future<RiderMe> fetchRiderMe(JivoApi api) async {
  try {
    final response = await api.dio.get<Object>('/api/v1/rider/me/');
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const ApiError(code: ApiErrorCode.unknown, statusCode: 200);
    }
    final profile = RiderProfile.fromJson(body);
    final cash = body['cash'];
    final flag = cash is Map ? cash['deposit_required'] : null;
    return RiderMe(
      profile,
      depositRequired: flag is bool ? flag : profile.cash.limitReached,
    );
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}
