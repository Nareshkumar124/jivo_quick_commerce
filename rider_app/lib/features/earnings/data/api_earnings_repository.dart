import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        EarningLine,
        EarningTypeEnum,
        Earnings,
        JivoApi,
        Payout,
        PayoutStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../shared/paging.dart';
import '../domain/earnings.dart' as domain;
import '../domain/earnings.dart' show DateRange, EarningsRepository;

/// `rider_earnings` and `rider_payouts_list` through the generated client
/// (P5 slice 5.4). Every amount is the server's string.
class ApiEarningsRepository implements EarningsRepository {
  ApiEarningsRepository(this._api);

  final JivoApi _api;

  @override
  Future<domain.EarningsSummary> fetchEarnings(DateRange range) async {
    try {
      final response = await _api.getRiderApi().riderEarnings(
        from: range.from,
        to: range.to,
      );
      return earningsOf(response.data!);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<Page<domain.Payout>> fetchPayouts({int? cursor}) async {
    try {
      final page = (await _api.getRiderApi().riderPayoutsList(
        page: cursor ?? 1,
      )).data!;
      return Page(
        items: [for (final payout in page.results) ?payoutOf(payout)],
        nextPage: pageOfNext(page.next),
        count: page.count,
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// An IST calendar date as the app holds it (a UTC-midnight value).
DateTime istDateOf(DateTime parsed) =>
    DateTime.utc(parsed.year, parsed.month, parsed.day);

domain.EarningType? earningTypeOf(EarningTypeEnum type) => switch (type) {
  EarningTypeEnum.BASE => domain.EarningType.base,
  EarningTypeEnum.DISTANCE => domain.EarningType.distance,
  EarningTypeEnum.TIP => domain.EarningType.tip,
  EarningTypeEnum.INCENTIVE => domain.EarningType.incentive,
  EarningTypeEnum.PENALTY => domain.EarningType.penalty,
  _ => null,
};

/// The pay lines of an order; a kind this app version does not know is
/// skipped (the order total still comes from the server).
List<domain.EarningLine> earningLinesOf(List<EarningLine> lines) => [
  for (final line in lines)
    if (earningTypeOf(line.type) case final type?)
      domain.EarningLine(
        type: type,
        amount: line.amount,
        note: line.note.trim().isEmpty ? null : line.note.trim(),
      ),
];

domain.EarningsSummary earningsOf(Earnings body) {
  final totals = body.totalsByType;
  return domain.EarningsSummary(
    from: istDateOf(body.from),
    to: istDateOf(body.to),
    total: body.total,
    ordersCount: body.ordersCount,
    totalsByType: {
      domain.EarningType.base: totals.BASE,
      domain.EarningType.distance: totals.DISTANCE,
      domain.EarningType.tip: totals.TIP,
      domain.EarningType.incentive: totals.INCENTIVE,
      domain.EarningType.penalty: totals.PENALTY,
    },
    orders: [
      for (final order in body.orders)
        domain.OrderEarning(
          orderNumber: order.orderNumber,
          completedAt: order.completedAt,
          total: order.total,
          lines: earningLinesOf(order.lines),
        ),
    ],
    ordersTruncated: body.ordersTruncated,
    adjustments: [
      for (final adjustment in body.adjustments)
        if (earningTypeOf(adjustment.type) case final type?)
          domain.EarningAdjustment(
            recordedAt: adjustment.recordedAt,
            line: domain.EarningLine(
              type: type,
              amount: adjustment.amount,
              note: adjustment.note.trim().isEmpty
                  ? null
                  : adjustment.note.trim(),
            ),
          ),
    ],
  );
}

domain.Payout? payoutOf(Payout payout) {
  final status = switch (payout.status) {
    PayoutStatusEnum.PENDING => domain.PayoutStatus.pending,
    PayoutStatusEnum.PAID => domain.PayoutStatus.paid,
    _ => null,
  };
  if (status == null) return null;
  return domain.Payout(
    id: payout.id,
    periodStart: istDateOf(payout.periodStart),
    periodEnd: istDateOf(payout.periodEnd),
    amount: payout.amount,
    status: status,
    reference: payout.reference,
    paidAt: payout.paidAt,
  );
}
