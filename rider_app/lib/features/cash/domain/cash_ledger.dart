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
    bool? depositRequired,
    this.homeStoreName,
  }) : depositRequired = depositRequired ?? limitReached;

  final String cashInHand;
  final String cashLimit;

  /// The server's verdict: at or above the limit, the rider gets prepaid
  /// orders only and must deposit cash. The app never compares amounts.
  final bool limitReached;

  /// `deposit_required` (DL-61 b): at the limit, or a COD order was skipped
  /// because cash in hand plus its amount was over the limit.
  final bool depositRequired;

  /// Where to deposit: the rider's home store (`home_store.name`).
  final String? homeStoreName;
}

/// `GET /rider/cash/ledger/?before_id=` with the summary (from
/// `GET /rider/me/`, api-requests #21) on the first page.
class CashLedgerPage {
  const CashLedgerPage({required this.entries, this.summary});

  /// Null on later pages: the screen keeps the one it has.
  final CashSummary? summary;
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
abstract interface class CashRepository {
  /// [cursor]: null for the newest entries, then the previous page's
  /// `nextPage` (a `before_id`; api-requests #24).
  Future<CashLedgerPage> fetchLedger({int? cursor});
}
