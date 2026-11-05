import 'package:jivo_core/jivo_core.dart';

import '../../task/domain/rider_task.dart';
import '../domain/today_summary.dart';

/// TODO(api): stand-in for the today summary and home store (home spec §11).
/// Dev flavor only (DL-30).
class FakeTodaySummary implements TodaySummaryRepository {
  FakeTodaySummary({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  static const sample = TodaySummary(
    deliveredCount: 6,
    earnedToday: '640.00',
    onlineSeconds: 11100,
    cashInHand: '1840.00',
    cashLimit: '5000.00',
    homeStoreName: 'Sector 18',
    homeStoreLocation: GeoPoint(28.5700, 77.3210),
  );

  TodaySummary summary = sample;

  ApiError? nextError;
  int calls = 0;

  @override
  Future<TodaySummary> fetch() async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return summary;
  }
}

class UnavailableTodaySummary implements TodaySummaryRepository {
  const UnavailableTodaySummary();

  @override
  Future<TodaySummary> fetch() async =>
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
}
