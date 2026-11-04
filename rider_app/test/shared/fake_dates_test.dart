import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/cash/data/fake_cash_backend.dart';
import 'package:rider_app/features/cash/domain/cash_ledger.dart';
import 'package:rider_app/features/earnings/data/fake_earnings_backend.dart';
import 'package:rider_app/features/earnings/domain/earnings.dart';
import 'package:rider_app/features/history/data/fake_history_backend.dart';
import 'package:rider_app/features/history/domain/task_history.dart';
import 'package:rider_app/features/onboarding/domain/validators.dart';
import 'package:rider_app/shared/fake_api_endpoint.dart';

/// The demo records must land on the IST days they are meant for once the
/// screens convert their instants back to IST (code review of T-225).
void main() {
  // 12:00 IST on Mon 2 Nov 2026, as in the widget-test harness.
  final now = DateTime.utc(2026, 11, 2, 6, 30);
  final today = DateTime.utc(2026, 11, 2);
  DateTime daysBack(int n) => today.subtract(Duration(days: n));

  group('istWallClock', () {
    test('IST wall time on an IST date, as a UTC instant', () {
      expect(istWallClock(today, 11, 40), DateTime.utc(2026, 11, 2, 6, 10));
      // Just after midnight IST is still the previous day in UTC.
      expect(istWallClock(today, 0, 15), DateTime.utc(2026, 11, 1, 18, 45));
    });

    test('stays on that IST day from 00:00 to 23:59', () {
      for (final (hour, minute) in [(0, 0), (5, 29), (5, 30), (23, 59)]) {
        expect(
          istToday(istWallClock(today, hour, minute)),
          today,
          reason: '$hour:$minute',
        );
      }
    });
  });

  test('history: four tasks a day from today back, newest first, none in '
      'the future', () async {
    final fake = FakeHistoryBackend(delay: Duration.zero, clock: () => now);
    final entries = <TaskHistoryEntry>[];
    int? page = 1;
    while (page != null) {
      final result = await fake.fetchHistory(page: page);
      entries.addAll(result.items);
      page = result.nextPage;
    }

    expect(entries, hasLength(23));
    for (final (i, entry) in entries.indexed) {
      expect(istToday(entry.completedAt), daysBack(i ~/ 4), reason: '#$i');
      expect(entry.completedAt.isAfter(now), isFalse, reason: '#$i');
      if (i > 0) {
        expect(
          entry.completedAt.isBefore(entries[i - 1].completedAt),
          isTrue,
          reason: 'newest first at #$i',
        );
      }
    }
    // The first task of today ended at 11:40 IST.
    expect(entries.first.completedAt, DateTime.utc(2026, 11, 2, 6, 10));
  });

  test('cash: today, then yesterday (deposit last), then three COD a day; '
      'newest first', () async {
    final fake = FakeCashBackend(delay: Duration.zero, clock: () => now);
    final entries = <CashEntry>[];
    int? page = 1;
    while (page != null) {
      final result = await fake.fetchLedger(page: page);
      entries.addAll(result.entries.items);
      page = result.entries.nextPage;
    }

    final dayOf = {for (final e in entries) e.id: istToday(e.recordedAt)};
    expect([dayOf[30], dayOf[29]], everyElement(today));
    expect([dayOf[28], dayOf[27]], everyElement(daysBack(1)));
    expect([dayOf[26], dayOf[25], dayOf[24]], everyElement(daysBack(1)));
    expect([dayOf[23], dayOf[22], dayOf[21]], everyElement(daysBack(2)));
    expect(dayOf[16], daysBack(4));
    for (var i = 1; i < entries.length; i++) {
      expect(
        entries[i].recordedAt.isBefore(entries[i - 1].recordedAt),
        isTrue,
        reason: 'newest first at #$i',
      );
    }
    expect(entries.every((e) => !e.recordedAt.isAfter(now)), isTrue);
  });

  test('earnings: every order and adjustment on the last day of the '
      'range', () async {
    final fake = FakeEarningsBackend(delay: Duration.zero);
    final range = DateRange(daysBack(2), today);
    final summary = await fake.fetchEarnings(range);

    for (final order in summary.orders) {
      expect(istToday(order.completedAt), today, reason: order.orderNumber);
      expect(order.completedAt.isAfter(now), isFalse);
    }
    for (final adjustment in summary.adjustments) {
      expect(istToday(adjustment.recordedAt), today);
      expect(adjustment.recordedAt.isAfter(now), isFalse);
    }
    expect(summary.orders.first.completedAt, DateTime.utc(2026, 11, 2, 6, 10));
  });
}
