import '../../../shared/paging.dart';
import '../../onboarding/domain/validators.dart';

/// Ledger entry kinds (07 §2.8 `RiderCashLedger.entry_type`).
enum CashEntryType {
  codCollected('COD_COLLECTED'),
  deposit('DEPOSIT'),
  adjustment('ADJUSTMENT');

  const CashEntryType(this.wireValue);

  final String wireValue;
}

/// One ledger row. Amounts are the server's strings (`"1249.00"`, deposits
/// `"-5000.00"`), including the running balance; nothing is summed here.
class CashEntry {
  const CashEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.recordedAt,
    this.orderNumber,
    this.note,
  });

  final int id;
  final CashEntryType type;
  final String amount;
  final String balanceAfter;
  final DateTime recordedAt;

  /// The order, for COD collected.
  final String? orderNumber;
  final String? note;
}

/// Cash in hand and the limit (04 §2.7), from the server.
class CashSummary {
  const CashSummary({
    required this.cashInHand,
    required this.cashLimit,
    required this.limitReached,
  });

  final String cashInHand;
  final String cashLimit;

  /// The server's verdict: at or above the limit, the rider gets prepaid
  /// orders only and must deposit cash. The app never compares amounts.
  final bool limitReached;
}

/// `GET /rider/cash/ledger/?page=` with the summary on the first page.
class CashLedgerPage {
  const CashLedgerPage({required this.summary, required this.entries});

  final CashSummary summary;
  final Page<CashEntry> entries;
}

/// Entries grouped by their IST date, newest day first (display only).
List<(DateTime day, List<CashEntry> entries)> groupByIstDay(
  List<CashEntry> entries,
) {
  final days = <DateTime, List<CashEntry>>{};
  for (final entry in entries) {
    days.putIfAbsent(istToday(entry.recordedAt), () => []).add(entry);
  }
  final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final day in keys) (day, days[day]!)];
}

/// The cash ledger (06 §3). Throws jivo_core's `ApiError`.
///
/// TODO(api): no rider contract yet; the fake stands in (DL-30 gating).
abstract interface class CashRepository {
  Future<CashLedgerPage> fetchLedger({int page = 1});
}
