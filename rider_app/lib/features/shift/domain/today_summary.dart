import 'package:flutter/foundation.dart';

import '../../task/domain/rider_task.dart';

/// Home's server data (`design/screens/rider/home.md` §3, §5, §6): the today
/// tiles, the cash-limit verdict and the home store. Every value is the
/// server's; the app adds nothing up. A null field is unknown and shows
/// "–", never 0.
///
/// TODO(api): home spec §11 #1 and #4 (`GET /rider/me/` or a shift
/// endpoint). Field names are assumptions until the contract lands.
@immutable
class TodaySummary {
  const TodaySummary({
    this.deliveredCount,
    this.earnedToday,
    this.onlineSeconds,
    this.cashInHand,
    this.cashLimit,
    this.limitReached = false,
    bool? depositRequired,
    this.homeStoreName,
    this.homeStoreLocation,
  }) : depositRequired = depositRequired ?? limitReached;

  final int? deliveredCount;

  /// Money strings as sent (`"640.00"`).
  final String? earnedToday;
  final String? cashInHand;
  final String? cashLimit;

  /// Time online today (IST day, as the server defines it), in seconds.
  final int? onlineSeconds;

  /// The server's verdict that cash in hand is at or over the limit: the
  /// rider gets prepaid offers only until a deposit (04 §2.7).
  final bool limitReached;

  /// `cash.deposit_required` (DL-61 b): show "Deposit cash". True at the
  /// limit, and also below it once a COD order was skipped because cash in
  /// hand plus its amount was over the limit. Cleared by a deposit.
  final bool depositRequired;

  /// For "Waiting for orders near {store}" and "Navigate to store".
  final String? homeStoreName;
  final GeoPoint? homeStoreLocation;
}

abstract interface class TodaySummaryRepository {
  Future<TodaySummary> fetch();
}

/// `5h 20m` / `45m` / `0m` for [TodaySummary.onlineSeconds] (display only).
String formatOnlineTime(int seconds) {
  final minutes = (seconds ~/ 60) % 60;
  final hours = seconds ~/ 3600;
  return hours == 0 ? '${minutes}m' : '${hours}h ${minutes}m';
}

/// Metres from a server error as km for display: one decimal (1840 →
/// `1.8`), no ".0" for whole km (2000 → `2`). Unit formatting only.
String formatKm(num metres) {
  final km = metres / 1000;
  final fixed = km.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
