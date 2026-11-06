import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/cash/data/api_cash_repository.dart';
import 'package:rider_app/features/cash/domain/cash_ledger.dart';
import 'package:rider_app/features/earnings/data/api_earnings_repository.dart';
import 'package:rider_app/features/earnings/domain/earnings.dart';
import 'package:rider_app/features/history/data/api_history_repository.dart';
import 'package:rider_app/features/shift/data/api_today_summary.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_rules.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/shared/paging.dart';

import '../../../fixtures/rider_contract_examples.dart';
import '../../../helpers/canned_http.dart';

const _ledger = '/api/v1/rider/cash/ledger/';
const _me = '/api/v1/rider/me/';
const _earnings = '/api/v1/rider/earnings/';
const _payouts = '/api/v1/rider/payouts/';
const _history = '/api/v1/rider/tasks/history/';

Map<String, Object?> _meWith({Object? depositRequired, bool limit = false}) {
  final cash = {
    ...(riderMeActiveExample['cash']! as Map<String, Object?>),
    'limit_reached': limit,
  };
  if (depositRequired != null) cash['deposit_required'] = depositRequired;
  return {...riderMeActiveExample, 'cash': cash};
}

void main() {
  late CannedAdapter http;

  setUp(() => http = CannedAdapter());

  group('paging links', () {
    test('before_id and page come from the next link', () {
      expect(
        beforeIdOfNext('https://x/api/v1/rider/cash/ledger/?before_id=880'),
        880,
      );
      expect(pageOfNext('https://x/api/v1/rider/payouts/?page=3'), 3);
      expect(beforeIdOfNext(null), isNull);
      expect(beforeIdOfNext('https://x/?page=2'), isNull);
      expect(pageOfNext('not a link ::'), isNull);
    });
  });

  group('ApiCashRepository', () {
    test('first page: entries as sent, the before_id cursor and the summary '
        'from /rider/me/ with deposit_required', () async {
      http.answers[_ledger] = const Canned(200, ledgerExample);
      http.answers[_me] = Canned(200, _meWith(depositRequired: true));
      final page = await ApiCashRepository(cannedApi(http)).fetchLedger();

      expect(page.entries.nextPage, 880);
      expect(page.entries.count, 57);
      final first = page.entries.items.first;
      expect(first.type, CashEntryType.codCollected);
      expect(first.amount, '498.00');
      expect(first.balanceAfter, '1250.00');
      expect(first.orderNumber, 'JV-261110-001203');
      expect(first.note, isNull, reason: 'a blank note is no note');
      final deposit = page.entries.items[1];
      expect(deposit.type, CashEntryType.deposit);
      expect(deposit.amount, '-1500.00');
      expect(deposit.note, 'Deposited at Jivo Sector 14');

      final summary = page.summary!;
      expect(summary.cashInHand, '1250.00');
      expect(summary.limitReached, isFalse);
      expect(summary.depositRequired, isTrue, reason: 'DL-61 b, below limit');
      expect(summary.homeStoreName, isNotNull);
      expect(
        http.requests.firstWhere((r) => r.path == _ledger).queryParameters,
        isNot(contains('before_id')),
      );
    });

    test('a later page sends before_id and carries no summary', () async {
      http.answers[_ledger] = const Canned(200, {
        'count': 57,
        'next': null,
        'previous': null,
        'results': [
          {
            'id': 3,
            'entry_type': 'SOMETHING_NEW',
            'amount': '1.00',
            'balance_after': '1.00',
            'order_number': null,
            'note': '',
            'recorded_at': '2026-11-01T08:30:00Z',
          },
        ],
      });
      final page = await ApiCashRepository(cannedApi(http))
          .fetchLedger(cursor: 880);

      expect(page.summary, isNull);
      expect(page.entries.items, isEmpty, reason: 'unknown types skipped');
      expect(page.entries.hasMore, isFalse);
      expect(http.requests.single.queryParameters['before_id'], 880);
      expect(http.requests.map((r) => r.path), isNot(contains(_me)));
    });

    test(
      'without deposit_required the verdict falls back to limit_reached',
      () async {
        http.answers[_ledger] = const Canned(200, ledgerExample);
        http.answers[_me] = Canned(200, _meWith(limit: true));
        final page = await ApiCashRepository(cannedApi(http)).fetchLedger();
        expect(page.summary!.depositRequired, isTrue);
      },
    );

    test('errors arrive as ApiError, also when /rider/me/ fails', () async {
      http.answers[_ledger] = Canned(503, errorBody('MAINTENANCE'));
      http.answers[_me] = const Canned.offline();
      await expectLater(
        ApiCashRepository(cannedApi(http)).fetchLedger(),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.maintenance,
          ),
        ),
      );

      http.answers[_ledger] = const Canned(200, ledgerExample);
      await expectLater(
        ApiCashRepository(cannedApi(http)).fetchLedger(),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.network),
        ),
      );
    });
  });

  group('ApiTodaySummary', () {
    test('home reads deposit_required next to limit_reached', () async {
      http.answers[_me] = Canned(200, _meWith(depositRequired: true));
      final summary = await ApiTodaySummary(cannedApi(http)).fetch();
      expect(summary.limitReached, isFalse);
      expect(summary.depositRequired, isTrue);
      expect(summary.cashInHand, '1250.00');
    });

    test('a body that is not an object is an error', () async {
      http.answers[_me] = const Canned(200, ['x']);
      await expectLater(
        ApiTodaySummary(cannedApi(http)).fetch(),
        throwsA(isA<ApiError>()),
      );
    });
  });

  group('ApiEarningsRepository', () {
    test('earnings: server totals as sent, IST dates in the query', () async {
      http.answers[_earnings] = const Canned(200, earningsDayExample);
      final summary = await ApiEarningsRepository(cannedApi(http))
          .fetchEarnings(
            DateRange(DateTime.utc(2026, 11, 10), DateTime.utc(2026, 11, 10)),
          );

      final query = http.requests.single.queryParameters;
      expect(query['from'], '2026-11-10');
      expect(query['to'], '2026-11-10');
      expect(summary.from, DateTime.utc(2026, 11, 10));
      expect(summary.total, '212.00');
      expect(summary.ordersCount, 4);
      expect(summary.totalsByType[EarningType.penalty], '-20.00');
      expect(summary.totalsByType[EarningType.tip], '40.00');
      expect(summary.ordersTruncated, isFalse);
      final order = summary.orders.single;
      expect(order.total, '62.00');
      expect(order.lines.map((l) => l.type), [
        EarningType.base,
        EarningType.distance,
        EarningType.tip,
      ]);
      expect(order.lines.first.note, isNull);
      expect(order.lines[1].note, '2.4 km');
      expect(summary.adjustments.map((a) => a.line.amount), [
        '20.00',
        '-20.00',
      ]);
    });

    test('an invalid range is a VALIDATION_ERROR', () async {
      http.answers[_earnings] = Canned(400, errorBody('VALIDATION_ERROR'));
      await expectLater(
        ApiEarningsRepository(cannedApi(http)).fetchEarnings(
          DateRange(DateTime.utc(2025, 1, 1), DateTime.utc(2026, 11, 10)),
        ),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.validationError,
          ),
        ),
      );
    });

    test('payouts: page numbers, dates and the UTR as sent', () async {
      http.answers[_payouts] = Canned(200, {
        ...payoutsExample,
        'next': 'https://api.jivo.in/api/v1/rider/payouts/?page=2',
      });
      final page = await ApiEarningsRepository(cannedApi(http)).fetchPayouts();

      expect(http.requests.single.queryParameters['page'], 1);
      expect(page.nextPage, 2);
      final [pending, paid] = page.items;
      expect(pending.status, PayoutStatus.pending);
      expect(pending.paidAt, isNull);
      expect(pending.periodStart, DateTime.utc(2026, 11, 3));
      expect(paid.status, PayoutStatus.paid);
      expect(paid.reference, 'UTR2026110412345');
      expect(paid.paidAt, DateTime.utc(2026, 11, 4, 19));
      expect(paid.amount, '5212.00');
    });
  });

  group('ApiHistoryRepository', () {
    test(
      'list: before_id paging, cancelled-before-pickup has no pay',
      () async {
        http.answers[_history] = const Canned(200, historyExample);
        final page = await ApiHistoryRepository(cannedApi(http)).fetchHistory();

        expect(page.nextPage, 6990);
        final [delivered, cancelled] = page.items;
        expect(delivered.status, TaskStatus.delivered);
        expect(delivered.payout, '62.00');
        expect(delivered.distanceKm, '2.40');
        expect(cancelled.status, TaskStatus.cancelled);
        expect(cancelled.payout, isNull);
        expect(cancelled.distanceKm, isNull);

        await ApiHistoryRepository(cannedApi(http)).fetchHistory(cursor: 6990);
        expect(http.requests.last.queryParameters['before_id'], 6990);
      },
    );

    test('detail: items, times, cash collected and pay lines', () async {
      http.answers['/api/v1/rider/tasks/history/7001/'] = const Canned(
        200,
        historyDetailExample,
      );
      final detail = await ApiHistoryRepository(cannedApi(http))
          .fetchDetail(7001);

      expect(http.requests.single.path, '/api/v1/rider/tasks/history/7001/');
      expect(detail.entry.orderNumber, 'JV-261110-001203');
      expect(detail.paymentType, PaymentType.cod);
      expect(detail.codCollected, '349.00');
      expect(detail.items.single.unit, '1 L');
      expect(detail.items.single.quantity, 2);
      expect(detail.itemCount, 2);
      expect(detail.pickedUpAt, DateTime.utc(2026, 11, 10, 9, 38, 40));
      expect(detail.failReason, isNull);
      expect(detail.earningsTotal, '62.00');
      expect(detail.earningLines, hasLength(3));
    });

    test('detail: a fail reason maps; another rider gets 404', () async {
      http.answers['/api/v1/rider/tasks/history/9/'] = Canned(200, {
        ...historyDetailExample,
        'task_id': 9,
        'status': 'RETURNED',
        'fail_reason': 'CUSTOMER_REFUSED',
        'earnings': null,
        'items': [],
      });
      final detail = await ApiHistoryRepository(cannedApi(http)).fetchDetail(9);
      expect(detail.failReason, FailReason.refused);
      expect(detail.earningsTotal, isNull);
      expect(detail.earningLines, isEmpty);

      http.answers['/api/v1/rider/tasks/history/10/'] = Canned(
        404,
        errorBody('NOT_FOUND'),
      );
      await expectLater(
        ApiHistoryRepository(cannedApi(http)).fetchDetail(10),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
        ),
      );
    });
  });
}
