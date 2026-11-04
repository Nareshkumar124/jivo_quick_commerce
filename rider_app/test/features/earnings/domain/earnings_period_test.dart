import 'package:flutter_test/flutter_test.dart';
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
}
