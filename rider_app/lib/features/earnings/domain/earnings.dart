import '../../../shared/paging.dart';
import '../../onboarding/domain/validators.dart';

/// Kinds of earning lines (07 §2.8 `RiderEarning.type`).
enum EarningType {
  base('BASE'),
  distance('DISTANCE'),
  tip('TIP'),
  incentive('INCENTIVE'),
  penalty('PENALTY');

  const EarningType(this.wireValue);

  final String wireValue;
}

/// One amount, exactly as the server sends it (`"45.00"`, penalties
/// `"-20.00"`). Never parsed or added up in the app.
class EarningLine {
  const EarningLine({required this.type, required this.amount, this.note});

  final EarningType type;
  final String amount;
  final String? note;
}

/// What the rider earned on one delivered order. [total] comes from the
/// server; the app does not add the [lines].
class OrderEarning {
  const OrderEarning({
    required this.orderNumber,
    required this.completedAt,
    required this.total,
    required this.lines,
  });

  final String orderNumber;
  final DateTime completedAt;
  final String total;
  final List<EarningLine> lines;
}

/// An incentive or penalty not tied to one order (e.g. a peak-hour bonus).
class EarningAdjustment {
  const EarningAdjustment({required this.line, required this.recordedAt});

  final EarningLine line;
  final DateTime recordedAt;
}

/// `GET /rider/earnings/?from=&to=` (06 §3, 04 §2.8): the totals per kind
/// and overall, all computed by the server, plus the per-order breakdown.
///
/// TODO(api): hand-written until the rider contract lands (end of P4).
class EarningsSummary {
  const EarningsSummary({
    required this.from,
    required this.to,
    required this.total,
    required this.ordersCount,
    required this.totalsByType,
    required this.orders,
    this.adjustments = const [],
  });

  /// The IST dates the summary covers (inclusive).
  final DateTime from;
  final DateTime to;
  final String total;
  final int ordersCount;

  /// The server's subtotal for each kind present (base, distance, tips,
  /// incentives, penalties).
  final Map<EarningType, String> totalsByType;
  final List<OrderEarning> orders;
  final List<EarningAdjustment> adjustments;
}

/// Payout status (07 §2.8 `Payout.status`).
enum PayoutStatus {
  pending('PENDING'),
  paid('PAID');

  const PayoutStatus(this.wireValue);

  final String wireValue;
}

/// A payout recorded by Finance (04 §2.8; payouts are made offline, D-16).
class Payout {
  const Payout({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.status,
    this.reference,
    this.paidAt,
  });

  final int id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String amount;
  final PayoutStatus status;

  /// The bank reference (UTR), once paid.
  final String? reference;
  final DateTime? paidAt;

  @override
  String toString() => 'Payout($id, ${status.wireValue})';
}

/// The periods the earnings screen offers (04 §2.8).
enum EarningsPeriod { today, thisWeek, custom }

/// An inclusive range of IST calendar dates (UTC-midnight values).
class DateRange {
  const DateRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Today, or this week (Monday to today), on the Indian calendar.
DateRange rangeFor(EarningsPeriod period, DateTime now) {
  final today = istToday(now);
  return switch (period) {
    EarningsPeriod.today => DateRange(today, today),
    EarningsPeriod.thisWeek => DateRange(
      today.subtract(Duration(days: today.weekday - DateTime.monday)),
      today,
    ),
    // The screen asks for the dates.
    EarningsPeriod.custom => DateRange(today, today),
  };
}

/// Earnings and payouts (06 §3). Every method throws jivo_core's `ApiError`.
///
/// TODO(api): no rider contract yet; the fake stands in (DL-30 gating).
abstract interface class EarningsRepository {
  /// `GET /rider/earnings/?from=YYYY-MM-DD&to=YYYY-MM-DD` (IST dates).
  Future<EarningsSummary> fetchEarnings(DateRange range);

  /// `GET /rider/payouts/?page=`.
  Future<Page<Payout>> fetchPayouts({int page = 1});
}
