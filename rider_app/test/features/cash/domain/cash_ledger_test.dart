import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/cash/domain/cash_ledger.dart';

void main() {
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
