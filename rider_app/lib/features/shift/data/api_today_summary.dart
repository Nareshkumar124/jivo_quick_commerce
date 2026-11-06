import 'package:jivo_api/jivo_api.dart' show JivoApi;

import '../../../shared/api/rider_me_reader.dart';
import '../../task/domain/rider_task.dart';
import '../domain/today_summary.dart';

/// Home's today tiles, cash verdict and home store from
/// `GET /rider/me/` (`today`, `cash`, `home_store`; P5 slices 5.1, 5.4).
class ApiTodaySummary implements TodaySummaryRepository {
  ApiTodaySummary(this._api);

  final JivoApi _api;

  @override
  Future<TodaySummary> fetch() async {
    final read = await fetchRiderMe(_api);
    final me = read.profile;
    return TodaySummary(
      deliveredCount: me.today.ordersDelivered,
      earnedToday: me.today.earnings,
      onlineSeconds: me.today.onlineSeconds,
      cashInHand: me.cash.cashInHand,
      cashLimit: me.cash.cashLimit,
      limitReached: me.cash.limitReached,
      depositRequired: read.depositRequired,
      homeStoreName: me.homeStore?.name,
      homeStoreLocation: switch (me.homeStore) {
        final store? => GeoPoint(store.lat, store.lng),
        null => null,
      },
    );
  }
}
