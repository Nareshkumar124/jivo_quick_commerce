import '../../../shared/paging.dart';
import '../../task/domain/task_status.dart';

/// A finished task (04 §2.8 "History").
class TaskHistoryEntry {
  const TaskHistoryEntry({
    required this.taskId,
    required this.orderNumber,
    required this.completedAt,
    required this.storeName,
    required this.dropLocality,
    required this.status,
    this.distanceKm,
    this.payout,
  });

  final int taskId;
  final String orderNumber;
  final DateTime completedAt;
  final String storeName;
  final String dropLocality;

  /// DELIVERED, RETURNED, CANCELLED (or FAILED while returning).
  final TaskStatus status;
  final String? distanceKm;

  /// What the rider earned on it, as the server sends it.
  final String? payout;
}

/// `GET /rider/tasks/history/?page=` (06 §3), newest first. Throws
/// jivo_core's `ApiError`.
///
/// TODO(api): no rider contract yet; the fake stands in (DL-30 gating).
abstract interface class TaskHistoryRepository {
  Future<Page<TaskHistoryEntry>> fetchHistory({int page = 1});
}
