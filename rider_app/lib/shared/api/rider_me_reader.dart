import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi, RiderProfile;
import 'package:jivo_core/jivo_core.dart';

/// `GET /rider/me/` (`rider_me_retrieve`) through the generated client.
/// Throws jivo_core's `ApiError` on failure.
Future<RiderProfile> fetchRiderMe(JivoApi api) async {
  try {
    return (await api.getRiderApi().riderMeRetrieve()).data!;
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}
