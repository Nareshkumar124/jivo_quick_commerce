import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi;
import 'package:jivo_core/jivo_core.dart';

import '../../task/domain/rider_task.dart';
import '../domain/today_summary.dart';

/// Home's today tiles, cash verdict and home store from
/// `GET /rider/me/` (`today`, `cash`, `home_store`; P5 slice 5.1).
class ApiTodaySummary implements TodaySummaryRepository {
  ApiTodaySummary(this._api);

  final JivoApi _api;

  @override
  Future<TodaySummary> fetch() async {
    try {
      final me = (await _api.getRiderApi().riderMeRetrieve()).data!;
      return TodaySummary(
        deliveredCount: me.today.ordersDelivered,
        earnedToday: me.today.earnings,
        onlineSeconds: me.today.onlineSeconds,
        cashInHand: me.cash.cashInHand,
        cashLimit: me.cash.cashLimit,
        limitReached: me.cash.limitReached,
        homeStoreName: me.homeStore?.name,
        homeStoreLocation: switch (me.homeStore) {
          final store? => GeoPoint(store.lat, store.lng),
          null => null,
        },
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}
