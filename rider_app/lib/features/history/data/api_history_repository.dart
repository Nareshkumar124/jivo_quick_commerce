import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart' as api show TaskHistoryDetail;
import 'package:jivo_api/jivo_api.dart' show JivoApi, TaskHistoryItem;
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

  @override
  Future<TaskHistoryDetail> fetchDetail(int taskId) async {
    try {
      final detail = (await _api.getRiderApi().riderTasksHistoryDetail(
        id: taskId,
      )).data!;
      return historyDetailOf(detail);
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

/// The generated `TaskHistoryDetail` mapped onto the screen's model.
TaskHistoryDetail historyDetailOf(api.TaskHistoryDetail body) =>
    TaskHistoryDetail(
      entry: TaskHistoryEntry(
        taskId: body.taskId,
        orderNumber: body.orderNumber,
        completedAt: body.completedAt,
        storeName: body.storeName,
        dropLocality: body.dropLocality,
        status: TaskStatus.fromWire(body.status.value),
        distanceKm: body.distanceKm,
        payout: body.payout,
      ),
      paymentType: PaymentType.fromWire(body.paymentType.value),
      codCollected: body.codCollected,
      items: [
        for (final item in body.items)
          HistoryItem(
            name: item.name,
            unit: switch (item.variant.trim()) {
              '' => null,
              final unit => unit,
            },
            quantity: item.quantity,
          ),
      ],
      itemCount: body.itemCount,
      assignedAt: body.assignedAt,
      pickedUpAt: body.pickedUpAt,
      deliveredAt: body.deliveredAt,
      failedAt: body.failedAt,
      failReason: FailReason.values
          .where((r) => r.wireValue == body.failReason?.value)
          .firstOrNull,
      returnedAt: body.returnedAt,
      cancelledAt: body.cancelledAt,
      earningsTotal: body.earnings?.total,
      earningLines: switch (body.earnings) {
        final earnings? => earningLinesOf(earnings.lines),
        null => const [],
      },
    );
