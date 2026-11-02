import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' as api;
import 'package:jivo_core/jivo_core.dart';

import '../../addresses/data/device_location.dart';
import '../../catalog/data/api_catalog_repository.dart' show storeFromApi;
import '../domain/delivery_location.dart';
import 'serviceability_repository.dart';

/// Serviceability and notify-me on the generated client (`06 §2.3`). The
/// check always answers 200; outside every area it is `serviceable: false`
/// with no store.
class ApiServiceabilityRepository implements ServiceabilityRepository {
  ApiServiceabilityRepository(this._api);

  final api.JivoApi _api;

  api.ServiceabilityApi get _serviceability => _api.getServiceabilityApi();

  @override
  Future<Serviceability> check(GeoPoint point) async {
    try {
      final result = (await _serviceability.serviceabilityCheck(
        lat: point.lat,
        lng: point.lng,
      )).data!;
      final store = result.store;
      return Serviceability(
        serviceable: result.serviceable,
        store: store == null ? null : storeFromApi(store),
        etaMinutes: result.etaMinutes,
        message: result.message,
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<void> notifyMe(GeoPoint point, {String? addressText}) async {
    final text = addressText?.trim();
    try {
      await _serviceability.serviceabilityNotifyMe(
        notifyMeRequest: api.NotifyMeRequest(
          lat: point.lat,
          lng: point.lng,
          addressText: text == null || text.isEmpty ? null : text,
        ),
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}
