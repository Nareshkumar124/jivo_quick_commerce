import '../../../shared/fake_api_endpoint.dart';
import '../../../shared/paging.dart';
import '../domain/earnings.dart';

/// TODO(api): stands in for `GET /rider/earnings/` and `GET /rider/payouts/`
/// (06 §3) until the rider contract lands (end of P4).
///
/// Every total here is a fixed string, as the server would send it: the app
/// must display them, never add the lines up.
class FakeEarningsBackend extends FakeApiEndpoint
    implements EarningsRepository {
  FakeEarningsBackend({
    super.delay = const Duration(milliseconds: 400),
    super.pageSize = 10,
  });

  @override
  Future<EarningsSummary> fetchEarnings(DateRange range) async {
    await recordCall(
      'fetchEarnings ${apiDate(range.from)}..${apiDate(range.to)}',
    );
    final oneDay = range.from == range.to;
    // Times on the last IST day of the range.
    final day = range.to;
    return EarningsSummary(
      from: range.from,
      to: range.to,
      // Deliberately not the sum of what is listed below: the server's
      // totals are shown as sent (and include orders not listed).
      total: oneDay ? '135.00' : '1842.50',
      ordersCount: oneDay ? 2 : 31,
      totalsByType: oneDay
          ? const {
              EarningType.base: '60.00',
              EarningType.distance: '25.00',
              EarningType.tip: '20.00',
              EarningType.incentive: '50.00',
              EarningType.penalty: '-20.00',
            }
          : const {
              EarningType.base: '930.00',
              EarningType.distance: '412.50',
              EarningType.tip: '180.00',
              EarningType.incentive: '400.00',
              EarningType.penalty: '-80.00',
            },
      orders: [
        OrderEarning(
          orderNumber: 'JQ-10501',
          completedAt: istWallClock(day, 11, 40),
          total: '65.00',
          lines: const [
            EarningLine(type: EarningType.base, amount: '30.00'),
            EarningLine(type: EarningType.distance, amount: '15.00'),
            EarningLine(type: EarningType.tip, amount: '20.00'),
          ],
        ),
        OrderEarning(
          orderNumber: 'JQ-10498',
          completedAt: istWallClock(day, 10, 10),
          total: '40.00',
          lines: const [
            EarningLine(type: EarningType.base, amount: '30.00'),
            EarningLine(type: EarningType.distance, amount: '10.00'),
          ],
        ),
      ],
      adjustments: [
        EarningAdjustment(
          recordedAt: istWallClock(day, 11),
          line: const EarningLine(
            type: EarningType.incentive,
            amount: '50.00',
            note: 'Peak-hour bonus',
          ),
        ),
        EarningAdjustment(
          recordedAt: istWallClock(day, 8, 30),
          line: const EarningLine(
            type: EarningType.penalty,
            amount: '-20.00',
            note: 'Late pickup',
          ),
        ),
      ],
    );
  }

  @override
  Future<Page<Payout>> fetchPayouts({int page = 1}) async {
    await recordCall('fetchPayouts $page');
    final all = [
      Payout(
        id: 12,
        periodStart: DateTime.utc(2026, 10, 26),
        periodEnd: DateTime.utc(2026, 11, 1),
        amount: '3120.00',
        status: PayoutStatus.pending,
      ),
      for (var i = 0; i < 14; i++)
        Payout(
          id: 11 - i,
          periodStart: DateTime.utc(
            2026,
            10,
            19,
          ).subtract(Duration(days: 7 * i)),
          periodEnd: DateTime.utc(2026, 10, 25).subtract(Duration(days: 7 * i)),
          amount: '${2800 + i * 15}.00',
          status: PayoutStatus.paid,
          reference: 'UTR4500${1200 + i}',
          // 19:00 UTC on the 26th is 00:30 IST on the 27th: the rider sees
          // the Indian date.
          paidAt: DateTime.utc(
            2026,
            10,
            26,
            19,
          ).subtract(Duration(days: 7 * i)),
        ),
    ];
    return pageOf(all, page);
  }
}
