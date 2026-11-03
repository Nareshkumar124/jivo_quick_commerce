import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/cash/domain/cash_ledger.dart';
import 'package:rider_app/features/earnings/domain/earnings.dart';

void main() {
  group('earnings periods (IST calendar)', () {
    test('today', () {
      final r = rangeFor(EarningsPeriod.today, DateTime.utc(2026, 11, 4, 6));
      expect(
        r,
        DateRange(DateTime.utc(2026, 11, 4), DateTime.utc(2026, 11, 4)),
      );
    });

    test('this week runs Monday to today', () {
      // Wednesday 4 Nov 2026.
      final wed = rangeFor(
        EarningsPeriod.thisWeek,
        DateTime.utc(2026, 11, 4, 6),
      );
      expect(wed.from, DateTime.utc(2026, 11, 2));
      expect(wed.to, DateTime.utc(2026, 11, 4));
      // Monday: just today.
      final mon = rangeFor(
        EarningsPeriod.thisWeek,
        DateTime.utc(2026, 11, 2, 6),
      );
      expect(mon.from, DateTime.utc(2026, 11, 2));
      // Sunday 8 Nov: from Monday 2 Nov.
      final sun = rangeFor(
        EarningsPeriod.thisWeek,
        DateTime.utc(2026, 11, 8, 6),
      );
      expect(sun.from, DateTime.utc(2026, 11, 2));
    });

    test('the IST date, not the phone zone: 19:00 UTC Sunday is Monday in '
        'India', () {
      final r = rangeFor(EarningsPeriod.today, DateTime.utc(2026, 11, 1, 19));
      expect(r.from, DateTime.utc(2026, 11, 2));
    });
  });

  group('cash ledger grouping (display only)', () {
    CashEntry entry(int id, DateTime at) => CashEntry(
      id: id,
      type: CashEntryType.codCollected,
      amount: '100.00',
      balanceAfter: '100.00',
      recordedAt: at,
    );

    test('by IST day, newest day first, entries kept in order', () {
      final groups = groupByIstDay([
        entry(3, DateTime.utc(2026, 11, 2, 10)),
        // 19:30 UTC on 1 Nov is 2 Nov in India.
        entry(2, DateTime.utc(2026, 11, 1, 19, 30)),
        entry(1, DateTime.utc(2026, 11, 1, 9)),
      ]);
      expect(groups.map((g) => g.$1), [
        DateTime.utc(2026, 11, 2),
        DateTime.utc(2026, 11, 1),
      ]);
      expect(groups.first.$2.map((e) => e.id), [3, 2]);
      expect(groups.last.$2.map((e) => e.id), [1]);
    });
  });
}
