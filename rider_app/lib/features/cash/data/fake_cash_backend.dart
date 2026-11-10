import '../../../shared/fake_api_endpoint.dart';
import '../../onboarding/domain/validators.dart';
import '../domain/cash_ledger.dart';

/// Stands in for `GET /rider/cash/ledger/` and the `cash` of
/// `GET /rider/me/` in `FAKE_API` builds and tests. The cursor is a page
/// number here (the API's is a `before_id`); the summary rides on the
/// first page only, like the API repository.
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

  /// A COD order was skipped below the limit (DL-61 b).
  bool codSkipped = false;

  @override
  Future<CashLedgerPage> fetchLedger({int? cursor}) async {
    final page = cursor ?? 1;
    await recordCall('fetchLedger $page');
    final today = istToday(_clock());
    final yesterday = today.subtract(const Duration(days: 1));
    final all = <CashEntry>[
      CashEntry(
        id: 30,
        type: CashEntryType.codCollected,
        amount: '1249.00',
        balanceAfter: limitReached ? '5249.00' : '2149.00',
        recordedAt: istWallClock(today, 11, 40),
        orderNumber: 'JQ-10501',
      ),
      CashEntry(
        id: 29,
        type: CashEntryType.codCollected,
        amount: '900.00',
        balanceAfter: limitReached ? '4000.00' : '900.00',
        recordedAt: istWallClock(today, 10, 10),
        orderNumber: 'JQ-10498',
      ),
      CashEntry(
        id: 28,
        type: CashEntryType.deposit,
        amount: '-3100.00',
        balanceAfter: '0.00',
        recordedAt: istWallClock(yesterday, 19, 30),
        note: 'Deposited at Jivo Sector 18',
      ),
      CashEntry(
        id: 27,
        type: CashEntryType.adjustment,
        amount: '-50.00',
        balanceAfter: '3100.00',
        recordedAt: istWallClock(yesterday, 18, 30),
        note: 'Short deposit corrected',
      ),
      for (var i = 0; i < 11; i++)
        CashEntry(
          id: 26 - i,
          type: CashEntryType.codCollected,
          amount: '${300 + i * 10}.00',
          balanceAfter: '${3150 - i * 250}.00',
          // Three a day from yesterday back, before that day's deposit.
          recordedAt: istWallClock(
            today.subtract(Duration(days: 1 + i ~/ 3)),
            const [16, 13, 11][i % 3],
            const [15, 40, 5][i % 3],
          ),
          orderNumber: 'JQ-10${480 - i}',
        ),
    ];
    return CashLedgerPage(
      summary: page != 1
          ? null
          : CashSummary(
              cashInHand: limitReached ? '5249.00' : '2149.00',
              cashLimit: '5000.00',
              limitReached: limitReached,
              depositRequired: limitReached || codSkipped,
              homeStoreName: 'Jivo Sector 18',
            ),
      entries: pageOf(all, page),
    );
  }
}
