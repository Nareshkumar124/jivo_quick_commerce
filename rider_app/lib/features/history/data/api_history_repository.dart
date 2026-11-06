import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show EarningLine, JivoApi, TaskHistoryItem;
import 'package:jivo_core/jivo_core.dart';

import '../../../shared/paging.dart';
import '../../earnings/data/api_earnings_repository.dart';
import '../../task/domain/rider_task.dart';
import '../../task/domain/task_rules.dart';
import '../../task/domain/task_status.dart';
import '../domain/task_history.dart';

/// `rider_tasks_history` through the generated client, paged by `before_id`
/// (api-requests #24), and `rider_tasks_history_detail` (P5 slice 5.4).
class ApiHistoryRepository implements TaskHistoryRepository {
  ApiHistoryRepository(this._api);

  final JivoApi _api;

  @override
  Future<Page<TaskHistoryEntry>> fetchHistory({int? cursor}) async {
    try {
      final page = (await _api.getRiderApi().riderTasksHistory(
        beforeId: cursor,
      )).data!;
      return Page(
        items: [for (final item in page.results) historyEntryOf(item)],
        nextPage: beforeIdOfNext(page.next),
        count: page.count,
      );
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  /// TODO(api): `rider_tasks_history_detail` is in the backend's slice 5.4
  /// schema but not yet in this worktree's generated client. Read with the
  /// shared Dio and the generated models until the PM regenerates
  /// `jivo_api`; then call `riderTasksHistoryDetail(id:)`.
  @override
  Future<TaskHistoryDetail> fetchDetail(int taskId) async {
    try {
      final response = await _api.dio.get<Object>(
        '/api/v1/rider/tasks/history/$taskId/',
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const ApiError(code: ApiErrorCode.unknown, statusCode: 200);
      }
      return historyDetailOf(body);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

TaskHistoryEntry historyEntryOf(TaskHistoryItem item) => TaskHistoryEntry(
  taskId: item.taskId,
  orderNumber: item.orderNumber,
  completedAt: item.completedAt,
  storeName: item.storeName,
  dropLocality: item.dropLocality,
  status: TaskStatus.fromWire(item.status.value),
  distanceKm: item.distanceKm,
  payout: item.payout,
);

/// The `TaskHistoryDetail` body. The list fields reuse the generated
/// `TaskHistoryItem` parser, the pay lines the generated `EarningLine`.
TaskHistoryDetail historyDetailOf(Map<String, dynamic> body) {
  DateTime? time(String key) => switch (body[key]) {
    final String value => DateTime.parse(value),
    _ => null,
  };
  final earnings = body['earnings'];
  final rawItems = body['items'];
  final rawLines = earnings is Map ? earnings['lines'] : null;
  return TaskHistoryDetail(
    entry: historyEntryOf(TaskHistoryItem.fromJson(body)),
    paymentType: PaymentType.fromWire(body['payment_type'] as String?),
    codCollected: body['cod_collected'] as String?,
    items: [
      if (rawItems is List)
        for (final item in rawItems.whereType<Map<String, dynamic>>())
          HistoryItem(
            name: item['name'] as String? ?? '',
            unit: switch (item['variant']) {
              final String v when v.trim().isNotEmpty => v.trim(),
              _ => null,
            },
            quantity: (item['quantity'] as num?)?.toInt() ?? 0,
          ),
    ],
    itemCount: (body['item_count'] as num?)?.toInt() ?? 0,
    assignedAt: time('assigned_at'),
    pickedUpAt: time('picked_up_at'),
    deliveredAt: time('delivered_at'),
    failedAt: time('failed_at'),
    failReason: FailReason.values
        .where((r) => r.wireValue == body['fail_reason'])
        .firstOrNull,
    returnedAt: time('returned_at'),
    cancelledAt: time('cancelled_at'),
    earningsTotal: earnings is Map ? earnings['total'] as String? : null,
    earningLines: rawLines is List
        ? earningLinesOf([
            for (final line in rawLines.whereType<Map<String, dynamic>>())
              EarningLine.fromJson(line),
          ])
        : const [],
  );
}
