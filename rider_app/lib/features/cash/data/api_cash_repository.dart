import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show CashEntryTypeEnum, CashLedgerEntry, JivoApi;
import 'package:jivo_core/jivo_core.dart';

import '../../../shared/api/rider_me_reader.dart';
import '../../../shared/paging.dart';
import '../domain/cash_ledger.dart';

/// `rider_cash_ledger` through the generated client, paged by `before_id`
/// (api-requests #24), with the summary from `GET /rider/me/` `cash`
/// (api-requests #21) on the first page (P5 slice 5.4).
class ApiCashRepository implements CashRepository {
  ApiCashRepository(this._api);

  final JivoApi _api;

  @override
  Future<CashLedgerPage> fetchLedger({int? cursor}) async {
    try {
      final ledger = _api.getRiderApi().riderCashLedger(beforeId: cursor);
      // In parallel; marked handled so a ledger failure does not leave an
      // unhandled error behind (awaiting it below still sees it).
      final me = cursor == null ? fetchRiderMe(_api) : null;
      me?.ignore();
      final page = (await ledger).data!;
      final read = await me;
      return CashLedgerPage(
        summary: switch (read) {
          null => null,
          final read => CashSummary(
            cashInHand: read.profile.cash.cashInHand,
            cashLimit: read.profile.cash.cashLimit,
            limitReached: read.profile.cash.limitReached,
            depositRequired: read.depositRequired,
            homeStoreName: read.profile.homeStore?.name,
          ),
        },
        entries: Page(
          items: [for (final entry in page.results) ?cashEntryOf(entry)],
          nextPage: beforeIdOfNext(page.next),
          count: page.count,
        ),
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// One ledger row, or null for an entry type this app version does not know
/// (skipped rather than shown wrong).
CashEntry? cashEntryOf(CashLedgerEntry entry) {
  final type = switch (entry.entryType) {
    CashEntryTypeEnum.COD_COLLECTED => CashEntryType.codCollected,
    CashEntryTypeEnum.DEPOSIT => CashEntryType.deposit,
    CashEntryTypeEnum.ADJUSTMENT => CashEntryType.adjustment,
    _ => null,
  };
  if (type == null) return null;
  final note = entry.note.trim();
  return CashEntry(
    id: entry.id,
    type: type,
    amount: entry.amount,
    balanceAfter: entry.balanceAfter,
    recordedAt: entry.recordedAt,
    orderNumber: entry.orderNumber,
    note: note.isEmpty ? null : note,
  );
}
