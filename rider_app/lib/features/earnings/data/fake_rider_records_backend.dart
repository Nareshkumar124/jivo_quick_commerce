import 'package:jivo_core/jivo_core.dart';

import '../../../shared/paging.dart';
import '../../cash/domain/cash_ledger.dart';
import '../../history/domain/task_history.dart';
import '../../task/domain/task_status.dart';
import '../domain/earnings.dart';

/// TODO(api): stands in for `GET /rider/earnings/`, `/rider/payouts/`,
/// `/rider/cash/ledger/` and `/rider/tasks/history/` (06 §3) until the rider
/// contract lands (end of P4).
///
/// Every total here is a fixed string, as the server would send it: the app
/// must display them, never add the lines up. Lists are paged like the API
/// (02 §5).
class FakeRiderRecordsBackend
    implements EarningsRepository, CashRepository, TaskHistoryRepository {
  FakeRiderRecordsBackend({
    this.delay = const Duration(milliseconds: 400),
    this.pageSize = 10,
  });

  final Duration delay;
  final int pageSize;

  /// Calls made, for tests.
  final List<String> calls = [];

  /// When set, the next call fails with it (then it is cleared).
  ApiError? failNext;

  /// The rider is at or above the cash limit (the server's verdict).
  bool limitReached = false;

  // ------------------------------------------------------------ earnings

  @override
  Future<EarningsSummary> fetchEarnings(DateRange range) async {
    await _call('fetchEarnings ${_date(range.from)}..${_date(range.to)}');
    final oneDay = range.from == range.to;
    final day = range.to;
    return EarningsSummary(
      from: range.from,
      to: range.to,
      // Deliberately not the sum of what is listed below: the server's
      // totals are shown as sent (and include orders on other pages).
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
          completedAt: day.add(const Duration(hours: 6, minutes: 10)),
          total: '65.00',
          lines: const [
            EarningLine(type: EarningType.base, amount: '30.00'),
            EarningLine(type: EarningType.distance, amount: '15.00'),
            EarningLine(type: EarningType.tip, amount: '20.00'),
          ],
        ),
        OrderEarning(
          orderNumber: 'JQ-10498',
          completedAt: day.add(const Duration(hours: 4, minutes: 40)),
          total: '40.00',
          lines: const [
            EarningLine(type: EarningType.base, amount: '30.00'),
            EarningLine(type: EarningType.distance, amount: '10.00'),
          ],
        ),
      ],
      adjustments: [
        EarningAdjustment(
          recordedAt: day.add(const Duration(hours: 8)),
          line: const EarningLine(
            type: EarningType.incentive,
            amount: '50.00',
            note: 'Peak-hour bonus',
          ),
        ),
        EarningAdjustment(
          recordedAt: day.add(const Duration(hours: 3)),
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
    await _call('fetchPayouts $page');
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
          paidAt: DateTime.utc(2026, 10, 27).subtract(Duration(days: 7 * i)),
        ),
    ];
    return _page(all, page);
  }

  // --------------------------------------------------------------- cash

  @override
  Future<CashLedgerPage> fetchLedger({int page = 1}) async {
    await _call('fetchLedger $page');
    final today = DateTime.utc(2026, 11, 2);
    final all = <CashEntry>[
      CashEntry(
        id: 30,
        type: CashEntryType.codCollected,
        amount: '1249.00',
        balanceAfter: limitReached ? '5249.00' : '2149.00',
        recordedAt: today.add(const Duration(hours: 6, minutes: 10)),
        orderNumber: 'JQ-10501',
      ),
      CashEntry(
        id: 29,
        type: CashEntryType.codCollected,
        amount: '900.00',
        balanceAfter: limitReached ? '4000.00' : '900.00',
        recordedAt: today.add(const Duration(hours: 4, minutes: 40)),
        orderNumber: 'JQ-10498',
      ),
      CashEntry(
        id: 28,
        type: CashEntryType.deposit,
        amount: '-3100.00',
        balanceAfter: '0.00',
        recordedAt: today.subtract(const Duration(hours: 10)),
        note: 'Deposited at Jivo Sector 18',
      ),
      for (var i = 0; i < 12; i++)
        CashEntry(
          id: 27 - i,
          type: CashEntryType.codCollected,
          amount: '${300 + i * 10}.00',
          balanceAfter: '${3100 - i * 250}.00',
          recordedAt: today.subtract(Duration(days: 1 + i ~/ 3, hours: 2)),
          orderNumber: 'JQ-10${480 - i}',
        ),
    ];
    return CashLedgerPage(
      summary: CashSummary(
        cashInHand: limitReached ? '5249.00' : '2149.00',
        cashLimit: '5000.00',
        limitReached: limitReached,
      ),
      entries: _page(all, page),
    );
  }

  // ------------------------------------------------------------ history

  @override
  Future<Page<TaskHistoryEntry>> fetchHistory({int page = 1}) async {
    await _call('fetchHistory $page');
    final today = DateTime.utc(2026, 11, 2);
    final statuses = [
      TaskStatus.delivered,
      TaskStatus.delivered,
      TaskStatus.returned,
      TaskStatus.delivered,
      TaskStatus.cancelled,
    ];
    final all = [
      for (var i = 0; i < 23; i++)
        TaskHistoryEntry(
          taskId: 600 - i,
          orderNumber: 'JQ-10${501 - i}',
          completedAt: today.subtract(Duration(hours: 3 * i)),
          storeName: 'Jivo Sector 18',
          dropLocality: i.isEven ? 'Sector 21, Noida' : 'Sector 27, Noida',
          status: statuses[i % statuses.length],
          distanceKm: '${2 + i % 4}.${i % 10}',
          payout: statuses[i % statuses.length] == TaskStatus.cancelled
              ? null
              : '${40 + i % 3 * 5}.00',
        ),
    ];
    return _page(all, page);
  }

  // ------------------------------------------------------------ helpers

  Page<T> _page<T>(List<T> all, int page) {
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, all.length);
    return Page(
      items: start >= all.length ? const [] : all.sublist(start, end),
      nextPage: end < all.length ? page + 1 : null,
      count: all.length,
    );
  }

  Future<void> _call(String name) async {
    calls.add(name);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
