import '../../../shared/fake_api_endpoint.dart';
import '../../onboarding/domain/validators.dart';
import '../domain/cash_ledger.dart';

/// TODO(api): stands in for `GET /rider/cash/ledger/` (06 §3) until the
/// rider contract lands (end of P4). The summary (cash in hand, limit and
/// the server's `limit_reached`) rides on every page here; where the real
/// API puts it is an open request (`/rider/me/` per 06 §3, or the ledger).
///
/// Cash in hand and every running balance are fixed strings, as the server
/// would send them: the app never adds the entries up.
class FakeCashBackend extends FakeApiEndpoint implements CashRepository {
  FakeCashBackend({
    DateTime Function()? clock,
    super.delay = const Duration(milliseconds: 400),
    super.pageSize = 10,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// The rider is at or above the cash limit (the server's verdict).
  bool limitReached = false;

  @override
  Future<CashLedgerPage> fetchLedger({int page = 1}) async {
    await recordCall('fetchLedger $page');
    final today = istToday(_clock());
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
      CashEntry(
        id: 27,
        type: CashEntryType.adjustment,
        amount: '-50.00',
        balanceAfter: '3100.00',
        recordedAt: today.subtract(const Duration(hours: 11)),
        note: 'Short deposit corrected',
      ),
      for (var i = 0; i < 11; i++)
        CashEntry(
          id: 26 - i,
          type: CashEntryType.codCollected,
          amount: '${300 + i * 10}.00',
          balanceAfter: '${3150 - i * 250}.00',
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
      entries: pageOf(all, page),
    );
  }
}
